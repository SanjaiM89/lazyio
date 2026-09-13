from fastapi import APIRouter

from app.db.crud.songs import search_library

router = APIRouter(prefix="/api/search", tags=["search"])


@router.get("")
async def search(q: str, song_limit: int = 8, album_limit: int = 8, artist_limit: int = 8):
    """Unified search: matching songs, albums and artists in one call."""
    return await search_library(
        q, song_limit=song_limit, album_limit=album_limit, artist_limit=artist_limit
    )
