"""Scan the Telegram source channel and index audio/video into MongoDB.

Grouping: songs with the same normalized name land in the same album
(see songs.album_key_for + rebuild_albums).
"""

import asyncio
import os
import re
import time

from app.db.connection import telegram_state_collection
from app.db.crud.songs import add_song, rebuild_albums
from app.services.telegram import telegram_client


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
    await telegram_client.start()
    state = await telegram_state_collection.find_one({"_id": "source_channel"}) or {}
    last_id = 0 if force else int(state.get("last_message_id", 0))

    scanned = 0
    added = 0
    skipped = 0
    max_id = last_id
    async for message in telegram_client.iter_messages(limit=limit):
        scanned += 1
        if message.id <= last_id:
            skipped += 1
            continue
        info = extract_track_info(message)
        if not info:
            skipped += 1
            continue
        try:
            await add_song(**info)
            added += 1
        except Exception as e:
            print(f"[INDEXER] add_song failed msg={message.id}: {e}")
        max_id = max(max_id, message.id)

    # regroup albums (cheap: rebuild only if something added)
    if added:
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
            }
        },
        upsert=True,
    )
    return {
        "scanned": scanned,
        "added": added,
        "skipped": skipped,
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
