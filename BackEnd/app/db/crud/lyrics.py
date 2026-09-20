"""Mongo persistence for fetched lyrics.

One document per song (unique ``song_id``) plus a ``match_key`` shared by
duplicate uploads of the same track, so re-uploads reuse a single lookup.
Negative results (no lyrics on LRCLIB / instrumental) are stored with
``found: false`` and expire after ``NEGATIVE_TTL`` — the same song is never
sent to the lyrics library twice, yet it is retried once a week in case the
library gains the track later.
"""

import asyncio
from datetime import datetime, timedelta, timezone

from app.db.connection import Database

lyrics_collection = Database.get_collection("lyrics")

# Re-check a track that had no lyrics only after this long.
NEGATIVE_TTL = timedelta(days=7)

# Hard cap on DB latency: lyrics must never hang on a sick database.
_DB_TIMEOUT = 3.0


def _now() -> datetime:
    return datetime.now(timezone.utc)


def match_key_for(title: str | None, artist: str | None, duration) -> str:
    """Stable key shared by duplicate uploads of the same track.

    Normalizes artist/title the same way albums are grouped and rounds the
    duration to a 5s bucket, so "Song (Official Video)" and "song_hq" from
    the same artist resolve to one key.
    """
    from app.db.crud.songs import (
        normalize_artist_for_grouping,
        normalize_title_for_grouping,
    )

    seconds = 0
    try:
        seconds = int(round(float(duration or 0)))
    except (TypeError, ValueError):
        seconds = 0
    return "|".join(
        (
            normalize_artist_for_grouping(artist) or "unknown artist",
            normalize_title_for_grouping(title) or "untitled",
            str(seconds // 5 * 5),
        )
    )


async def _find(query: dict) -> dict | None:
    try:
        return await asyncio.wait_for(
            lyrics_collection.find_one(query), timeout=_DB_TIMEOUT
        )
    except Exception:
        # Unreachable DB must never break lyrics: fall through to the library.
        return None


def _usable(doc: dict) -> bool:
    """A stored hit is always usable; a miss only until it expires."""
    if doc.get("found"):
        return True
    fetched_at = doc.get("fetched_at")
    if not isinstance(fetched_at, datetime):
        return False
    if fetched_at.tzinfo is None:
        fetched_at = fetched_at.replace(tzinfo=timezone.utc)
    return _now() - fetched_at <= NEGATIVE_TTL


async def get_cached_lyrics(
    song_id: str | None = None, match_key: str | None = None
) -> dict | None:
    """Stored lyrics for a song (or an identical upload), else None.

    ``None`` also covers an unreachable DB and expired misses — callers then
    fall through to the lyrics library.
    """
    if song_id:
        doc = await _find({"song_id": str(song_id)})
        if doc and _usable(doc):
            return doc
    if match_key:
        doc = await _find({"match_key": match_key})
        if doc and _usable(doc):
            return doc
    return None


async def save_lyrics(song_id: str, match_key: str, payload: dict | None) -> bool:
    """Upsert the lookup result (best-effort). Returns True when written."""
    if not song_id:
        return False
    payload = payload or {}
    document = {
        "song_id": str(song_id),
        "match_key": match_key,
        "found": bool(payload),
        "source": payload.get("source"),
        "instrumental": bool(payload.get("instrumental")),
        "synced": bool(payload.get("synced")),
        "lines": payload.get("lines") or [],
        "plain": payload.get("plain") or "",
        "matched": payload.get("matched") or {},
        "fetched_at": _now(),
        "updated_at": _now(),
    }
    try:
        await asyncio.wait_for(
            lyrics_collection.update_one(
                {"song_id": document["song_id"]},
                {"$set": document},
                upsert=True,
            ),
            timeout=_DB_TIMEOUT,
        )
        return True
    except Exception as exc:
        print(f"[LYRICS] cache write skipped ({type(exc).__name__}: {exc})")
        return False


async def delete_lyrics_for_song(song_id: str) -> None:
    """Drop stored lyrics when the song itself is deleted (best-effort)."""
    try:
        await asyncio.wait_for(
            lyrics_collection.delete_many({"song_id": str(song_id)}),
            timeout=_DB_TIMEOUT,
        )
    except Exception:
        pass


async def ensure_lyrics_indexes() -> None:
    """Unique per-song row + shared key for duplicate uploads (best-effort)."""
    try:
        await lyrics_collection.create_index("song_id", unique=True)
    except Exception:
        pass
    try:
        await lyrics_collection.create_index("match_key")
    except Exception:
        pass
