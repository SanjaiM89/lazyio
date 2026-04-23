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
    success = await delete_song(song_id)
    if not success:
        raise HTTPException(status_code=404, detail="Song not found")
    await notify_update("library_updated")
    return {"status": "success", "message": "Song deleted"}


@router.post("/{song_id}/play")
async def mark_song_played(song_id: str):
    await record_play(song_id)
    return {"status": "success"}
