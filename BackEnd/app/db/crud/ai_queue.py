from datetime import datetime
from app.db.connection import Database
from app.db.crud.songs import get_all_songs, get_song_by_id
from app.db.crud.likes import get_liked_songs

ai_queue_collection = Database.get_collection("ai_queue")


async def get_ai_queue() -> dict:
    queue = await ai_queue_collection.find_one({"_id": "main_queue"})
    if queue:
        return {
            "song_ids": queue.get("song_ids", []),
            "played_ids": queue.get("played_ids", []),
            "created_at": queue.get("created_at"),
            "updated_at": queue.get("updated_at"),
        }
    return {"song_ids": [], "played_ids": [], "created_at": None, "updated_at": None}


async def save_ai_queue(song_ids: list) -> bool:
    existing = await ai_queue_collection.find_one({"_id": "main_queue"})
    now = datetime.utcnow()

    if existing:
        await ai_queue_collection.update_one(
            {"_id": "main_queue"}, {"$set": {"song_ids": song_ids, "updated_at": now}}
        )
    else:
        await ai_queue_collection.insert_one(
            {
                "_id": "main_queue",
                "song_ids": song_ids,
                "played_ids": [],
                "created_at": now,
                "updated_at": now,
            }
        )
    return True


async def mark_song_played(song_id: str) -> bool:
    queue = await ai_queue_collection.find_one({"_id": "main_queue"})
    if not queue:
        return False

    song_ids = queue.get("song_ids", [])
    played_ids = queue.get("played_ids", [])

    if song_id in song_ids:
        song_ids.remove(song_id)
    if song_id not in played_ids:
        played_ids.append(song_id)

    await ai_queue_collection.update_one(
        {"_id": "main_queue"},
        {
            "$set": {
                "song_ids": song_ids,
                "played_ids": played_ids,
                "updated_at": datetime.utcnow(),
            }
        },
    )
    return True


async def clear_played_queue() -> bool:
    await ai_queue_collection.update_one(
        {"_id": "main_queue"}, {"$set": {"played_ids": []}}
    )
    return True


async def get_queue_songs() -> list:
    queue = await get_ai_queue()
    songs = []
    for song_id in queue["song_ids"]:
        song = await get_song_by_id(song_id)
        if song:
            songs.append(song)
    return songs


async def refill_queue_if_needed(min_songs: int = 10) -> bool:
    queue = await get_ai_queue()
    current_count = len(queue["song_ids"])

    if current_count >= min_songs:
        return False

    needed = min_songs - current_count
    played_ids = set(queue["played_ids"])
    current_ids = set(queue["song_ids"])

    all_songs = await get_all_songs()
    available = [
        s for s in all_songs if s["id"] not in played_ids and s["id"] not in current_ids
    ]

    liked = await get_liked_songs()
    liked_ids = {s["id"] for s in liked}

    liked_available = [s for s in available if s["id"] in liked_ids]
    others = [s for s in available if s["id"] not in liked_ids]

    import random

    random.shuffle(others)

    candidates = liked_available + others
    new_song_ids = [s["id"] for s in candidates[:needed]]

    if new_song_ids:
        updated_queue = queue["song_ids"] + new_song_ids
        await save_ai_queue(updated_queue)
        return True

    return False
