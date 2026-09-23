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


async def analyze_local_file(song_id: str, path: str, delete_after: bool = False,
                             vocal: bool = True, vocal_threshold: float = 0.2) -> bool:
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
        if vocal:
            await fuse_and_store_vocal(song_id, path, threshold=vocal_threshold)
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


async def fuse_and_store_vocal(song_id: str, path: str, threshold: float = 0.2) -> dict | None:
    """Run vocal language ID + fuse with the stored label (Step 4).

    Always persists ``audio_vocal`` evidence; writes ``language`` only
    per the fusion policy (manual labels sacred, overrides need 0.8+).
    """
    from app.services.vocal_lang import analyze_vocal_language, resolve_language
    from app.db.crud.songs import get_song_raw_by_id, save_song_vocal, set_song_language

    try:
        vocal = analyze_vocal_language(path, threshold=threshold)
        if not vocal:
            return None
        await save_song_vocal(song_id, vocal)
        raw = await get_song_raw_by_id(song_id)
        if not raw:
            return vocal
        lang, source = resolve_language(
            raw.get("language"), raw.get("language_source"),
            vocal.get("language"), vocal.get("confidence", 0.0),
            threshold=threshold,
        )
        if lang:
            await set_song_language(song_id, lang, source=source)
            try:
                from app.db.crud.search_engine import mark_search_index_dirty

                mark_search_index_dirty()
            except Exception:
                pass
        return vocal
    except Exception as e:
        logger.warning(f"vocal fusion failed for {song_id}: {e}")
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
    """Fast metadata-only backfill of song languages (no audio needed).

    Pass 1 labels from title/artist/genre text. Pass 2 propagates within
    an artist: if >= 2 labeled songs agree (>= 60%), unlabeled songs by
    the same artist inherit it (source ``auto:artist``). This covers
    Latin-script catalogs (e.g. Kollywood) where pass 1 finds nothing.
    """
    from app.db.connection import songs_collection
    from app.services.language import detect_language, normalize_language

    stats = {"checked": 0, "labeled": 0, "propagated": 0, "unknown": 0}
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
    stats["propagated"] = await _propagate_artist_languages()
    if stats["labeled"] or stats["propagated"]:
        try:
            from app.db.crud.search_engine import mark_search_index_dirty

            mark_search_index_dirty()
        except Exception:
            pass
    return stats


async def _propagate_artist_languages(min_labeled: int = 2, agreement: float = 0.6) -> int:
    """Label unlabeled songs from same-artist consensus. Returns count."""
    from app.db.connection import songs_collection
    from app.services.language import normalize_language
    import re

    buckets = {}
    cursor = songs_collection.find(
        {}, projection={"artist": 1, "language": 1}
    )
    async for doc in cursor:
        raw = (doc.get("artist") or "").strip()
        if not raw or raw in ("Unknown Artist", "Unknown"):
            continue
        key = re.sub(r"[^a-z0-9]+", " ", raw.lower()).strip()
        b = buckets.setdefault(key, {"labeled": {}, "unlabeled": []})
        lang = normalize_language(doc.get("language") or "")
        if lang:
            b["labeled"][lang] = b["labeled"].get(lang, 0) + 1
        else:
            b["unlabeled"].append(doc["_id"])
    propagated = 0
    for b in buckets.values():
        total = sum(b["labeled"].values())
        if total < min_labeled or not b["unlabeled"]:
            continue
        best, n = max(b["labeled"].items(), key=lambda kv: kv[1])
        if n / total < agreement:
            continue
        res = await songs_collection.update_many(
            {"_id": {"$in": b["unlabeled"]}},
            {"$set": {"language": best, "language_source": "auto:artist"}},
        )
        propagated += res.modified_count
    return propagated


async def analyze_library_job(limit: int = 50, force: bool = False, max_mb: int = 150,
                              vocal: bool = True, vocal_threshold: float = 0.2) -> dict:
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
            if vocal:
                await fuse_and_store_vocal(sid, src, threshold=vocal_threshold)
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
