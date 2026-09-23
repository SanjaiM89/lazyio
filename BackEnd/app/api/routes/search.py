from fastapi import APIRouter, Query

from app.db.crud.songs import search_library, suggest_library

router = APIRouter(prefix="/api/search", tags=["search"])


@router.get("")
async def search(q: str, song_limit: int = 8, album_limit: int = 8, artist_limit: int = 8,
                 song_offset: int = 0):
    """Unified search: matching songs, albums and artists in one call."""
    return await search_library(
        q, song_limit=song_limit, album_limit=album_limit, artist_limit=artist_limit,
        song_offset=song_offset,
    )


@router.get("/suggest")
async def suggest(
    q: str = Query(..., min_length=1, max_length=100), limit: int = 6
):
    """As-you-type autocomplete: minimal id/title/artist payload."""
    return await suggest_library(q, limit=max(1, min(limit, 10)))
