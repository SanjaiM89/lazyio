"""Scan the Telegram source channel and index audio/video into MongoDB.

Grouping: songs with the same normalized name land in the same album
(see songs.album_key_for + rebuild_albums).
"""

import asyncio
import os
import re
import time

from app.db.connection import telegram_state_collection
from app.db.crud.songs import (
    add_song,
    rebuild_albums,
    get_song_by_telegram_id,
    GROUPING_VERSION,
    GENERIC_ALBUMS,
    GENERIC_ARTISTS,
)
from app.services.telegram import telegram_client

# Bump to re-run the album-correction pass (wrong albums from unvalidated
# store matches get corrected toward validated matches). v2 retried songs
# whose earlier lookups found no match. v3 re-queues rows poisoned by
# transient store errors that were wrongly marked as checked/no-match.
META_FIX_VERSION = 3


async def _enrich_from_store(info: dict) -> bool:
    """Fill missing cover/album/artist/year/genre via the iTunes match.

    Returns True if anything was filled. Only fills placeholders —
    never overwrites real Telegram metadata.
    """
    needs_art = not info.get("cover_art")
    needs_album = not info.get("album") or info.get("album") in GENERIC_ALBUMS
    needs_artist = not info.get("artist") or info.get("artist") in GENERIC_ARTISTS
    needs_year = not info.get("year")
    needs_genre = not info.get("genre")
    if not (needs_art or needs_album or needs_artist or needs_year or needs_genre):
        return False
    from app.services.artwork import fetch_track_meta, TransientStoreError

    changed = False
    try:
        meta = await fetch_track_meta(info.get("title", ""), info.get("artist", ""))
    except TransientStoreError as e:
        # Transport failure (timeout / rate-limit / HTTP error): do NOT mark
        # checked — the next scan must retry instead of blacklisting the song.
        print(f"[INDEXER] transient store error, will retry next scan: {e}")
        info["meta_checked"] = False
        info["meta_match"] = False
        return False
    info["meta_match"] = meta is not None
    if meta:
        if needs_art and meta.get("artwork"):
            info["cover_art"] = meta["artwork"]
            info["thumbnail"] = meta["artwork"]
            changed = True
        if needs_album and meta.get("album"):
            info["album"] = meta["album"]
            changed = True
        if needs_artist and meta.get("artist"):
            info["artist"] = meta["artist"]
            changed = True
        if needs_year and meta.get("year"):
            info["year"] = meta["year"]
            changed = True
        if needs_genre and meta.get("genre"):
            info["genre"] = meta["genre"]
            changed = True
    # Fully resolved (or proven unmatchable) => never re-query this song.
    # Partial fills stay unchecked so later scans retry the missing bits.
    still_missing = (
        not info.get("cover_art")
        or not info.get("album")
        or info.get("album") in GENERIC_ALBUMS
        or not info.get("artist")
        or info.get("artist") in GENERIC_ARTISTS
        or not info.get("year")
    )
    info["meta_checked"] = (meta is None) or not still_missing
    return changed


AUDIO_EXTS = (".mp3", ".m4a", ".flac", ".wav", ".ogg", ".opus", ".aac")
VIDEO_EXTS = (".mp4", ".mkv", ".webm", ".avi", ".mov")


def _clean(value: str | None, fallback: str) -> str:
    if value and str(value).strip():
        return str(value).strip()
    return fallback


def _parse_caption(caption: str | None, file_name: str):
    """Try 'Artist - Title' from caption or filename."""
    text = (caption or "").strip()
    if " - " in text:
        parts = [p.strip() for p in text.split(" - ", 1)]
        if parts[0] and parts[1]:
            return parts[0], re.sub(r"\s+", " ", parts[1].split("\n")[0])
    base = os.path.splitext(os.path.basename(file_name or ""))[0]
    base = re.sub(r"[_\.]+", " ", base).strip()
    if " - " in base:
        a, t = [p.strip() for p in base.split(" - ", 1)]
        return a or "Unknown Artist", t or base
    return "Unknown Artist", base or file_name or "Untitled"


def extract_track_info(message) -> dict | None:
    try:
        if not message or not message.media:
            return None
        # Non-file media (photos, polls, stickers, webpage previews, ...)
        # has no downloadable document — skip silently.
        file = getattr(message, "file", None)
        if file is None:
            return None
        file_name = file.name or f"telegram_{message.id}"
        lower = file_name.lower()
        mime_type = file.mime_type or ""
        is_audio = lower.endswith(AUDIO_EXTS) or mime_type.startswith("audio")
        is_video = lower.endswith(VIDEO_EXTS) or mime_type.startswith("video")
        if not (is_audio or is_video):
            return None

        title = None
        artist = None
        duration = 0
        # Telethon document attributes carry real metadata
        try:
            document = getattr(message, "document", None)
            for attr in (document.attributes if document else []):
                cls = attr.__class__.__name__
                if cls == "DocumentAttributeAudio":
                    title = getattr(attr, "title", None) or title
                    artist = getattr(attr, "performer", None) or artist
                    duration = int(getattr(attr, "duration", 0) or 0)
                elif cls == "DocumentAttributeVideo":
                    duration = int(getattr(attr, "duration", 0) or duration)
                elif cls == "DocumentAttributeFilename":
                    pass
        except Exception:
            pass

        caption = (message.message or message.text or "").strip() if hasattr(
            message, "message"
        ) else ""
        # caption may hold album info on third line? keep simple
        def_artist, def_title = _parse_caption(caption, file_name)
        title = _clean(title, def_title)
        artist = _clean(artist, def_artist)
        album = "Unknown Album"
        # heuristic: caption line 2 could be album
        if caption and "\n" in caption:
            second = caption.split("\n")[1].strip()
            if second and len(second) < 80:
                album = second

        return {
            "telegram_message_id": message.id,
            "title": title,
            "artist": artist,
            "album": album,
            "duration": duration,
            "file_name": file_name,
            "file_size": file.size or 0,
            "mime_type": mime_type,
            "has_video": bool(is_video),
            "source_channel": str(telegram_client.source_channel),
        }
    except Exception as e:
        print(f"[INDEXER] extract failed for msg {getattr(message, 'id', '?')}: {e}")
        return None


async def scan_source_channel(limit: int = 0, force: bool = False) -> dict:
    """Index the source channel into MongoDB.

    Incremental by message id: Telegram only returns messages newer than the
    stored last_message_id (server-side min_id filter), so repeat scans are
    cheap. Dedupe is by telegram message id — one DB row per message, enforced
    by a partial unique index plus an explicit pre-check below.
    force=True re-walks the full history (backfill / repair).
    """
    await telegram_client.start()
    state = await telegram_state_collection.find_one({"_id": "source_channel"}) or {}
    last_id = 0 if force else int(state.get("last_message_id", 0))

    scanned = 0
    added = 0
    skipped = 0
    duplicates = 0
    max_id = last_id
    # min_id => server only sends newer messages; no full-history re-walk.
    async for message in telegram_client.iter_messages(limit=limit, min_id=last_id):
        scanned += 1
        max_id = max(max_id, message.id)
        # Dedupe: skip messages already fully indexed (covers force-rescans
        # and any state loss). Anything not fully resolved is re-processed
        # once so enrichment/backfill flags converge, then skipped after.
        existing = await get_song_by_telegram_id(message.id)
        if existing and existing.get("meta_checked"):
            skipped += 1
            duplicates += 1
            continue
        info = extract_track_info(message)
        if not info:
            skipped += 1
            continue
        try:
            await _enrich_from_store(info)
            await add_song(**info)
            added += 1
        except Exception as e:
            print(f"[INDEXER] add_song failed msg={message.id}: {e}")

    # Backfill metadata for already-indexed songs (bounded per scan so bulk
    # libraries converge over a few scans without hammering the lookup API).
    # Songs already checked with no match are skipped (negative caching).
    backfilled = 0
    try:
        from app.db.connection import songs_collection

        cursor = songs_collection.find(
            {
                "meta_checked": {"$ne": True},
                "$or": [
                    {"cover_art": None},
                    {"cover_art": ""},
                    {"album": None},
                    {"album": ""},
                    {"album": "Unknown Album"},
                    {"artist": None},
                    {"artist": ""},
                    {"artist": "Unknown Artist"},
                    {"year": None},
                ],
            }
        ).limit(50)
        candidates = [song async for song in cursor]
        # Concurrent lookups (bounded) so big libraries drain in minutes,
        # not hours. The store helper still spaces individual calls.
        sem = asyncio.Semaphore(3)

        async def _lookup(song):
            async with sem:
                info = {
                    "title": song.get("title", ""),
                    "artist": song.get("artist", ""),
                    "album": song.get("album"),
                    "cover_art": song.get("cover_art"),
                    "year": song.get("year"),
                    "genre": song.get("genre"),
                }
                changed = await _enrich_from_store(info)
                return song, info, changed

        results = await asyncio.gather(
            *[_lookup(s) for s in candidates], return_exceptions=True
        )
        for r in results:
            if isinstance(r, Exception):
                # One bad song must never abort the whole batch.
                print(f"[INDEXER] backfill item failed: {r}")
                continue
            song, info, changed = r
            updates = {}
            if "meta_checked" in info:
                updates["meta_checked"] = info["meta_checked"]
                updates["meta_match"] = info.get("meta_match", False)
            if changed:
                if info.get("cover_art"):
                    updates["cover_art"] = info["cover_art"]
                    updates["thumbnail"] = info["cover_art"]
                if info.get("album") and (
                    song.get("album") in GENERIC_ALBUMS
                    or info["album"] not in GENERIC_ALBUMS
                ):
                    updates["album"] = info["album"]
                if info.get("artist") and (
                    song.get("artist") in GENERIC_ARTISTS
                    or info["artist"] not in GENERIC_ARTISTS
                ):
                    updates["artist"] = info["artist"]
                if info.get("year") and not song.get("year"):
                    updates["year"] = info["year"]
                if info.get("genre") and not song.get("genre"):
                    updates["genre"] = info["genre"]
                from app.db.crud.songs import album_key_for

                updates["album_key"] = album_key_for(
                    song.get("title"), updates.get("artist", song.get("artist")),
                    updates.get("album", song.get("album")),
                )
                backfilled += 1
            await songs_collection.update_one({"_id": song["_id"]}, {"$set": updates})
    except Exception as e:
        print(f"[INDEXER] metadata backfill warning: {e}")

    # One-time correction of previously stored albums: earlier scans had no
    # match validation, so some songs may carry a wrong album/cover from a
    # bad store match. Re-validate (bounded) and correct toward the validated
    # match; songs with no valid match are left untouched.
    corrected = 0
    try:
        from app.db.connection import songs_collection as _songs
        from app.db.crud.songs import normalize_text as _norm
        from app.services.artwork import fetch_track_meta as _fetch
        from app.services.artwork import TransientStoreError as _Transient

        if force or state.get("meta_fix_version") != META_FIX_VERSION:
            # Past lookups that found no match get one retry with the
            # improved (fallback + validated) matcher.
            retry_reset = await _songs.update_many(
                {"meta_match": False},
                {"$set": {"meta_checked": False}},
            )
            if retry_reset.modified_count:
                print(f"[INDEXER] queued {retry_reset.modified_count} songs for meta retry")
            cursor = _songs.find(
                {
                    "album": {
                        "$nin": [None, "", "Unknown Album", "Unknown", "Telegram", "Audio"]
                    }
                }
            ).limit(500 if force else 200)
            async for song in cursor:
                try:
                    meta = await _fetch(song.get("title", ""), song.get("artist", ""))
                except _Transient as e:
                    # Throttled: stop the pass, retry next scan.
                    print(f"[INDEXER] correction paused (transient): {e}")
                    break
                if not meta or not meta.get("album"):
                    continue
                if _norm(meta["album"]) == _norm(song.get("album")):
                    continue
                updates = {"album": meta["album"]}
                if meta.get("artwork"):
                    updates["cover_art"] = meta["artwork"]
                    updates["thumbnail"] = meta["artwork"]
                if meta.get("year") and not song.get("year"):
                    updates["year"] = meta["year"]
                if meta.get("genre") and not song.get("genre"):
                    updates["genre"] = meta["genre"]
                from app.db.crud.songs import album_key_for as _akf

                updates["album_key"] = _akf(
                    song.get("title"), song.get("artist"), meta["album"]
                )
                await _songs.update_one({"_id": song["_id"]}, {"$set": updates})
                corrected += 1
                print(
                    f"[INDEXER] corrected album: {song.get('title')!r} "
                    f"{song.get('album')!r} -> {meta['album']!r}"
                )
    except Exception as e:
        print(f"[INDEXER] album correction warning: {e}")

    # Regroup albums only when something changed (new/updated songs, cover
    # backfill, album corrections) or when the grouping rules version changed.
    # Albums are fully derived data, so rebuilding is safe.
    grouping_changed = state.get("grouping_version") != GROUPING_VERSION
    if added or backfilled or corrected or grouping_changed:
        await rebuild_albums()

    await telegram_state_collection.update_one(
        {"_id": "source_channel"},
        {
            "$set": {
                "channel": str(telegram_client.source_channel),
                "last_message_id": max_id,
                "last_scan_at": time.time(),
                "last_scanned": scanned,
                "last_added": added,
                "last_duplicates": duplicates,
                "last_backfilled": backfilled,
                "last_corrected": corrected,
                "grouping_version": GROUPING_VERSION,
                "meta_fix_version": META_FIX_VERSION,
            }
        },
        upsert=True,
    )
    return {
        "scanned": scanned,
        "added": added,
        "skipped": skipped,
        "duplicates": duplicates,
        "backfilled": backfilled,
        "corrected": corrected,
        "last_message_id": max_id,
        "channel": str(telegram_client.source_channel),
    }


async def start_periodic_rescan(interval_seconds: int = 600):
    while True:
        await asyncio.sleep(interval_seconds)
        try:
            result = await scan_source_channel()
            print(f"[INDEXER] periodic scan: {result}")
            try:
                from app.api.routes.websocket import notify_update

                await notify_update("library_updated")
            except Exception:
                pass
        except Exception as e:
            print(f"[INDEXER] periodic scan failed: {e}")
