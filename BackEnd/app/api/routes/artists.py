from fastapi import APIRouter, HTTPException

from app.db.crud.songs import get_artists, get_artist_detail

router = APIRouter(prefix="/api/artists", tags=["artists"])


@router.get("")
async def list_artists(page: int = 1, limit: int = 20, query: str = None):
    return await get_artists(page=page, limit=limit, query=query)


@router.get("/{name}")
async def get_artist(name: str):
    artist = await get_artist_detail(name)
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    return artist
