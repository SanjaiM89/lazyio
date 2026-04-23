from app.db.connection import Database
from app.db.crud.songs import get_song_by_id
from datetime import datetime

likes_collection = Database.get_collection("likes")


async def like_song(song_id: str) -> bool:
    await likes_collection.update_one(
        {"song_id": song_id},
        {"$set": {"song_id": song_id, "liked": True, "updated_at": datetime.utcnow()}},
        upsert=True,
    )
    return True


async def dislike_song(song_id: str) -> bool:
    await likes_collection.update_one(
        {"song_id": song_id},
        {"$set": {"song_id": song_id, "liked": False, "updated_at": datetime.utcnow()}},
        upsert=True,
    )
    return True


async def remove_like(song_id: str) -> bool:
    result = await likes_collection.delete_one({"song_id": song_id})
    return result.deleted_count > 0


async def get_like_status(song_id: str) -> dict:
    doc = await likes_collection.find_one({"song_id": song_id})
    if doc:
        return {"liked": doc.get("liked")}
    return {"liked": None}


async def get_liked_songs() -> list:
    song_ids = []
    async for doc in likes_collection.find({"liked": True}):
        song_ids.append(doc["song_id"])

    songs = []
    for sid in song_ids:
        song = await get_song_by_id(sid)
        if song:
            songs.append(song)
    return songs
