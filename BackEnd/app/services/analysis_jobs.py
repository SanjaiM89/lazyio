"""Background audio-analysis jobs (Phase 1).

- ``analyze_local_file``: analyze a file already on disk (upload flow),
  persist the feature dict + FAISS vector, refresh the in-memory index.
- ``analyze_library_job``: backfill for the Telegram-scanned library.
  Prefers complete cache files (``cache/audio/<message_id>.bin``);
  otherwise streams a bounded prefix via the Telegram client into temp
  storage. Files larger than ``max_mb`` are skipped unless cached.
"""

import asyncio
import logging
import os
import tempfile

logger = logging.getLogger("AnalysisJobs")

PREFIX_BYTES = 12 * 1024 * 1024  # enough for ~60-90 s of typical encodes


async def analyze_local_file(song_id: str, path: str, delete_after: bool = False) -> bool:
    """Analyze *path* for *song_id*; optionally delete the file afterwards."""
    from app.services.audio_analysis import analyze_file, features_to_vector
    from app.db.crud.songs import save_song_audio
    from app.ai.recommender import audio_recommender

    try:
        loop = asyncio.get_running_loop()
        features = await loop.run_in_executor(None, analyze_file, path)
        if not features:
            return False
        vector = features_to_vector(features)
        await save_song_audio(song_id, features, vector)
        audio_recommender.add_to_index(song_id, vector)
        return True
    except Exception as e:
        logger.warning(f"analyze_local_file failed for {song_id}: {e}")
        return False
    finally:
        if delete_after:
            try:
                if path and os.path.exists(path):
                    os.remove(path)
            except OSError:
                pass


def _cached_audio_path(message_id, expected_size: int = 0) -> str | None:
    """Complete on-disk cache file for a Telegram message, if present.

    Only returns the path when the file size matches ``expected_size``
    (when known), so stale/partial cache entries are never analyzed.
    """
    try:
        from app.services import audio_cache

        final = audio_cache._final(int(message_id))
        try:
            size = final.stat().st_size
        except OSError:
            return None
        if size <= 0:
            return None
        if expected_size and size != int(expected_size):
            return None
        return str(final)
    except Exception:
        return None


async def _download_prefix(message_id: int, file_size: int) -> str | None:
    """Stream the head of a Telegram file into a temp file for analysis."""
    from app.services.telegram import telegram_client

    try:
        fd, tmp = tempfile.mkstemp(prefix="lazyio-anlib-", suffix=".bin")
        os.close(fd)
        limit = min(PREFIX_BYTES, file_size or PREFIX_BYTES)
        written = 0
        async for chunk in telegram_client.stream_file(message_id, offset=0, limit=limit):
            with open(tmp, "ab") as f:
                f.write(chunk)
            written += len(chunk)
            if written >= limit:
                break
        if written > 65536:
            return tmp
        try:
            os.remove(tmp)
        except OSError:
            pass
        return None
    except Exception as e:
        logger.warning(f"prefix download failed for msg {message_id}: {e}")
        return None


async def detect_library_languages(limit: int = 500, force: bool = False) -> dict:
    """Fast metadata-only backfill of song languages (no audio needed)."""
    from app.db.connection import songs_collection
    from app.services.language import detect_language

    stats = {"checked": 0, "labeled": 0, "unknown": 0}
    query = {} if force else {"$or": [{"language": {"$exists": False}}, {"language": None}]}
    cursor = songs_collection.find(
        query, projection={"title": 1, "artist": 1, "album": 1, "genre": 1}
    ).limit(limit)
    async for doc in cursor:
        stats["checked"] += 1
        lang, _detail = detect_language(
            doc.get("title"), doc.get("artist"), doc.get("album"), doc.get("genre")
        )
        if lang:
            await songs_collection.update_one(
                {"_id": doc["_id"]},
                {"$set": {"language": lang, "language_source": "auto"}},
            )
            stats["labeled"] += 1
        else:
            stats["unknown"] += 1
    if stats["labeled"]:
        try:
            from app.db.crud.search_engine import mark_search_index_dirty

            mark_search_index_dirty()
        except Exception:
            pass
    return stats


async def analyze_library_job(limit: int = 50, force: bool = False, max_mb: int = 150) -> dict:
    """Backfill audio descriptors + vectors. Returns a summary dict."""
    from app.db.connection import songs_collection
    from app.db.crud.songs import save_song_audio
    from app.services.audio_analysis import analyze_file, features_to_vector
    from app.ai.recommender import audio_recommender

    stats = {"checked": 0, "analyzed": 0, "skipped": 0, "failed": 0}
    query = {} if force else {"audio": {"$exists": False}}
    cursor = songs_collection.find(query, projection={
        "telegram_message_id": 1, "file_size": 1, "has_video": 1,
    }).limit(limit)

    async for doc in cursor:
        stats["checked"] += 1
        sid = str(doc["_id"])
        msg_id = doc.get("telegram_message_id")
        if not msg_id:
            stats["skipped"] += 1
            continue
        size = doc.get("file_size") or 0
        if size > max_mb * 1024 * 1024:
            # Only analyze huge files when fully cached locally already.
            cached = _cached_audio_path(msg_id, size)
            if not cached:
                stats["skipped"] += 1
                continue
            src, temp = cached, False
        else:
            cached = _cached_audio_path(msg_id, size)
            if cached:
                src, temp = cached, False
            else:
                src = await _download_prefix(int(msg_id), size)
                temp = True
                if not src:
                    stats["failed"] += 1
                    continue
        try:
            loop = asyncio.get_running_loop()
            features = await loop.run_in_executor(None, analyze_file, src)
            if not features:
                stats["failed"] += 1
                continue
            vector = features_to_vector(features)
            await save_song_audio(sid, features, vector)
            audio_recommender.add_to_index(sid, vector)
            stats["analyzed"] += 1
        except Exception as e:
            logger.warning(f"library analysis failed for {sid}: {e}")
            stats["failed"] += 1
        finally:
            if temp:
                try:
                    os.remove(src)
                except OSError:
                    pass
    return stats
