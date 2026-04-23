from bson import ObjectId
from app.db.connection import history_collection, songs_collection
from app.db.crud.songs import get_song_by_id
from datetime import datetime, timedelta


async def record_play(song_id: str):
    await history_collection.insert_one(
        {"song_id": song_id, "played_at": datetime.utcnow()}
    )

    try:
        await songs_collection.update_one(
            {"_id": ObjectId(song_id)}, {"$inc": {"play_count": 1}}
        )
    except Exception as e:
        print(f"Error incrementing play count: {e}")


async def get_recently_played(limit: int = 10) -> list:
    since = datetime.utcnow() - timedelta(days=7)

    pipeline = [
        {"$match": {"played_at": {"$gte": since}}},
        {"$sort": {"played_at": -1}},
        {"$group": {"_id": "$song_id", "last_played": {"$first": "$played_at"}}},
        {"$sort": {"last_played": -1}},
        {"$limit": limit},
    ]

    song_ids = []
    async for doc in history_collection.aggregate(pipeline):
        song_ids.append(doc["_id"])

    songs = []
    for sid in song_ids:
        song = await get_song_by_id(sid)
        if song:
            songs.append(song)

    return songs
