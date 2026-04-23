from bson import ObjectId
from app.db.connection import playlists_collection
from app.db.crud.songs import get_song_by_id


def playlist_helper(playlist) -> dict:
    return {
        "id": str(playlist["_id"]),
        "name": playlist.get("name", "Untitled"),
        "songs": playlist.get("songs", []),
        "cover_art": playlist.get("cover_art"),
        "created_at": playlist.get("created_at"),
        "is_ai_generated": playlist.get("is_ai_generated", False),
    }


async def create_playlist(
    name: str, songs: list = None, cover_art: str = None, is_ai: bool = False
) -> str:
    from datetime import datetime

    data = {
        "name": name,
        "songs": songs or [],
        "cover_art": cover_art,
        "created_at": datetime.utcnow(),
        "is_ai_generated": is_ai,
    }
    result = await playlists_collection.insert_one(data)
    return str(result.inserted_id)


async def get_playlists(page: int = 1, limit: int = 10) -> dict:
    skip = (page - 1) * limit
    total = await playlists_collection.count_documents({})

    playlists = []
    async for pl in (
        playlists_collection.find().sort("created_at", -1).skip(skip).limit(limit)
    ):
        p_data = playlist_helper(pl)

        if p_data.get("songs") and len(p_data["songs"]) > 0:
            first_song_id = p_data["songs"][0]
            song = await get_song_by_id(first_song_id)
            if song and song.get("cover_art"):
                p_data["cover_image"] = song["cover_art"]

        playlists.append(p_data)

    return {
        "playlists": playlists,
        "page": page,
        "total": total,
        "pages": (total + limit - 1) // limit if total > 0 else 1,
    }


async def get_playlist_by_id(playlist_id: str) -> dict:
    try:
        pl = await playlists_collection.find_one({"_id": ObjectId(playlist_id)})
        if pl:
            return playlist_helper(pl)
    except:
        pass
    return None


async def add_song_to_playlist(playlist_id: str, song_id: str) -> bool:
    try:
        result = await playlists_collection.update_one(
            {"_id": ObjectId(playlist_id)}, {"$addToSet": {"songs": song_id}}
        )
        return result.modified_count > 0
    except:
        return False


async def remove_song_from_playlist(playlist_id: str, song_id: str) -> bool:
    try:
        result = await playlists_collection.update_one(
            {"_id": ObjectId(playlist_id)}, {"$pull": {"songs": song_id}}
        )
        return result.modified_count > 0
    except:
        return False


async def delete_playlist(playlist_id: str) -> bool:
    try:
        result = await playlists_collection.delete_one({"_id": ObjectId(playlist_id)})
        return result.deleted_count > 0
    except:
        return False


async def get_all_app_playlists():
    # Helper needed if there are "app-wide" playlists
    # Current codebase fetches all playlists or uses create_app_playlist.
    # For now, implemented for `get_homepage_recommendations`
    total = await playlists_collection.count_documents({})
    return await get_playlists(page=1, limit=total)


async def create_app_playlist(name: str, songs: list, description: str = ""):
    # Used for generated playlists like AI ones
    existing = await playlists_collection.find_one(
        {"name": name, "is_ai_generated": True}
    )
    if existing:
        await playlists_collection.update_one(
            {"_id": existing["_id"]}, {"$set": {"songs": songs}}
        )
        return str(existing["_id"])
    return await create_playlist(name, songs, is_ai=True)
