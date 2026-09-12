from fastapi import APIRouter, HTTPException

from app.db.crud.songs import get_albums_paginated, get_album_with_songs

router = APIRouter(prefix="/api/albums", tags=["albums"])


@router.get("")
async def list_albums(page: int = 1, limit: int = 20):
    return await get_albums_paginated(page=page, limit=limit)


@router.get("/{album_id}")
async def get_album(album_id: str):
    album = await get_album_with_songs(album_id)
    if not album:
        raise HTTPException(status_code=404, detail="Album not found")
    return album
