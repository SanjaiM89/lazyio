import asyncio

from fastapi import APIRouter, HTTPException
from typing import Optional

from app.db.crud.songs import (
    get_all_songs,
    search_songs,
    delete_song,
    get_songs_paginated,
    get_song_raw_by_id,
)
from app.db.crud.lyrics import delete_lyrics_for_song
from app.db.crud.history import record_play
from app.services.lyrics import TransientLyricsError, get_lyrics_for_song
from app.api.routes.websocket import notify_update

router = APIRouter(prefix="/api/songs", tags=["songs"])

# Strong refs to in-flight warm-up tasks (asyncio can GC unreferenced tasks).
_warm_tasks: set = set()


async def _warm_lyrics(song: dict) -> None:
    """Background pre-fetch so opening the Lyrics tab is instant.

    A stored result (including "no lyrics") makes this a no-op, so a song is
    only ever looked up once.
    """
    try:
        await get_lyrics_for_song(song)
    except Exception as exc:
        print(f"[LYRICS] warm-up skipped: {exc}")


def _schedule_warm_lyrics(song: dict) -> None:
    task = asyncio.create_task(_warm_lyrics(song))
    _warm_tasks.add(task)
    task.add_done_callback(_warm_tasks.discard)


@router.get("")
async def get_songs(query: Optional[str] = None):
    if query:
        return await search_songs(query)
    return await get_all_songs()


@router.get("/paginated")
async def get_songs_page(page: int = 1, limit: int = 20):
    return await get_songs_paginated(page=page, limit=limit)


@router.delete("/{song_id}")
async def remove_song(song_id: str):
    raw = await get_song_raw_by_id(song_id)
    success = await delete_song(song_id)
    if not success:
        raise HTTPException(status_code=404, detail="Song not found")
    # Best-effort: drop stored lyrics as well
    await delete_lyrics_for_song(song_id)
    # Best-effort: remove the Telegram message as well
    if raw and raw.get("telegram_message_id"):
        try:
            from app.services.telegram import telegram_client

            await telegram_client.delete_message(int(raw["telegram_message_id"]))
        except Exception as e:
            print(f"[SONGS] Telegram delete skipped: {e}")
    await notify_update("library_updated")
    return {"status": "success", "message": "Song deleted"}


@router.post("/{song_id}/play")
async def mark_song_played(song_id: str):
    await record_play(song_id)
    raw = await get_song_raw_by_id(song_id)
    if raw:
        # Warm the lyrics cache in the background (no-op once stored).
        _schedule_warm_lyrics(raw)
    return {"status": "success"}


@router.get("/{song_id}/lyrics")
async def get_song_lyrics(song_id: str, refresh: bool = False):
    """Lyrics for one track, persisted after the first lookup.

    Served from Mongo (written on first request) so the same song never
    reaches the lyrics library twice. 404 = no lyrics for this track.
    """
    raw = await get_song_raw_by_id(song_id)
    if not raw:
        raise HTTPException(status_code=404, detail="Song not found")
    try:
        result = await get_lyrics_for_song(raw, refresh=refresh)
    except TransientLyricsError as exc:
        raise HTTPException(
            status_code=503, detail=f"Lyrics service unavailable: {exc}"
        )
    lyrics = result["lyrics"]
    if lyrics is None:
        raise HTTPException(status_code=404, detail="No lyrics found for this track")
    return {"song_id": song_id, "cached": result["cached"], **lyrics}
