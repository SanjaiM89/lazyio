from fastapi import APIRouter, HTTPException
from typing import Optional

from app.db.crud.songs import (
    get_all_songs,
    search_songs,
    delete_song,
    get_songs_paginated,
)
from app.db.crud.history import record_play
from app.api.routes.websocket import notify_update

router = APIRouter(prefix="/api/songs", tags=["songs"])


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
    from app.db.crud.songs import get_song_raw_by_id

    raw = await get_song_raw_by_id(song_id)
    success = await delete_song(song_id)
    if not success:
        raise HTTPException(status_code=404, detail="Song not found")
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
    return {"status": "success"}
