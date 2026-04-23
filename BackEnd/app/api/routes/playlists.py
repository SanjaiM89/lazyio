from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.db.crud.playlists import (
    create_playlist,
    get_playlists,
    get_playlist_by_id,
    add_song_to_playlist,
    remove_song_from_playlist,
    delete_playlist,
)
from app.api.routes.websocket import notify_update

router = APIRouter(prefix="/api/playlists", tags=["playlists"])


class CreatePlaylistRequest(BaseModel):
    name: str
    songs: list = []


@router.post("")
async def api_create_playlist(req: CreatePlaylistRequest):
    new_id = await create_playlist(name=req.name, songs=req.songs)
    await notify_update("library_updated")
    return {"status": "success", "id": new_id, "name": req.name}


@router.get("")
async def list_playlists(page: int = 1, limit: int = 10):
    return await get_playlists(page=page, limit=limit)


@router.get("/{playlist_id}")
async def api_get_playlist(playlist_id: str):
    pl = await get_playlist_by_id(playlist_id)
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")
    return pl


@router.post("/{playlist_id}/songs/{song_id}")
async def api_add_song_to_playlist(playlist_id: str, song_id: str):
    success = await add_song_to_playlist(playlist_id, song_id)
    if not success:
        raise HTTPException(status_code=400, detail="Could not add song")
    await notify_update("library_updated")
    return {"status": "success"}


@router.delete("/{playlist_id}/songs/{song_id}")
async def api_remove_song_from_playlist(playlist_id: str, song_id: str):
    success = await remove_song_from_playlist(playlist_id, song_id)
    if not success:
        raise HTTPException(status_code=400, detail="Could not remove song")
    await notify_update("library_updated")
    return {"status": "success"}


@router.delete("/{playlist_id}")
async def api_delete_playlist(playlist_id: str):
    success = await delete_playlist(playlist_id)
    if not success:
        raise HTTPException(status_code=404, detail="Playlist not found")
    await notify_update("library_updated")
    return {"status": "success"}


@router.post("/import-app-playlist/{playlist_id}")
async def import_app_playlist(playlist_id: str):
    app_pl = await get_playlist_by_id(playlist_id)
    if not app_pl:
        raise HTTPException(status_code=404, detail="App Playlist not found")

    name = app_pl.get("name", "Imported Playlist")
    song_ids = app_pl.get("songs", [])

    new_id = await create_playlist(name=name, songs=song_ids)
    await notify_update("library_updated")

    return {"status": "success", "id": new_id, "name": name}
