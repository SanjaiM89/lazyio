from bson import ObjectId
from app.db.connection import Database
from app.db.crud.songs import get_all_songs, get_song_by_id

app_playlists_collection = Database.get_collection("app_playlists")


async def get_app_playlists() -> list:
    cursor = app_playlists_collection.find().sort("created_at", -1)
    playlists = []
    async for p in cursor:
        p["id"] = str(p["_id"])
        del p["_id"]
        playlists.append(p)
    return playlists


async def create_app_playlist(
    name: str, song_ids: list, description: str = "", cover_image: str = None
) -> str:
    from datetime import datetime

    if not cover_image and song_ids:
        first_song = await get_song_by_id(song_ids[0])
        if first_song:
            cover_image = first_song.get("cover_art")

    result = await app_playlists_collection.insert_one(
        {
            "name": name,
            "description": description,
            "song_ids": song_ids,
            "cover_image": cover_image,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        }
    )
    return str(result.inserted_id)


async def get_playlist_with_songs(playlist_id: str) -> dict:
    try:
        playlist = await app_playlists_collection.find_one(
            {"_id": ObjectId(playlist_id)}
        )
        if not playlist:
            return None

        playlist["id"] = str(playlist["_id"])
        del playlist["_id"]

        full_songs = []
        for sid in playlist.get("song_ids", []):
            s = await get_song_by_id(sid)
            if s:
                full_songs.append(s)

        playlist["songs"] = full_songs
        return playlist
    except:
        return None


async def init_default_playlists():
    count = await app_playlists_collection.count_documents({})
    if count == 0:
        all_songs = await get_all_songs()
        if not all_songs:
            return

        import random

        recent = sorted(all_songs, key=lambda x: x.get("id", ""), reverse=True)[:10]
        if recent:
            await create_app_playlist(
                "Fresh Arrivals",
                [s["id"] for s in recent],
                "Newest tracks in your library",
            )

        if len(all_songs) >= 5:
            mix = random.sample(all_songs, min(15, len(all_songs)))
            await create_app_playlist(
                "Random Mix", [s["id"] for s in mix], "A bit of everything"
            )
