import os
import motor.motor_asyncio
from bson import ObjectId
from dotenv import load_dotenv

# Load env from root or current dir
load_dotenv("config.env")
load_dotenv("../config.env")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise ValueError("DATABASE_URL is not set")

client = motor.motor_asyncio.AsyncIOMotorClient(DATABASE_URL)
db = client.get_database("music_app")
songs_collection = db.get_collection("songs")

def song_helper(song) -> dict:
    return {
        "id": str(song["_id"]),
        "telegram_file_id": song.get("telegram_file_id"),
        "title": song.get("title"),
        "artist": song.get("artist"),
        "album": song.get("album"),
        "duration": song.get("duration"),
        "cover_art": song.get("cover_art"),
        "file_name": song.get("file_name"),
        "file_size": song.get("file_size"),
    }

async def init_db():
    # Motor handles connection pooling automatically
    pass

async def add_song(telegram_file_id: str, title: str, artist: str, album: str, duration: int, cover_art: str, file_name: str, file_size: int):
    # Check for duplicates by file_name or title+artist combo
    existing = await songs_collection.find_one({
        "$or": [
            {"file_name": file_name},
            {"title": title, "artist": artist}
        ]
    })
    if existing:
        return str(existing["_id"])  # Return existing song ID instead of creating duplicate
    
    song_data = {
        "telegram_file_id": telegram_file_id,
        "title": title,
        "artist": artist,
        "album": album,
        "duration": duration,
        "cover_art": cover_art,
        "file_name": file_name,
        "file_size": file_size
    }
    new_song = await songs_collection.insert_one(song_data)
    return str(new_song.inserted_id)

async def get_all_songs():
    songs = []
    async for song in songs_collection.find().sort("_id", -1):
        songs.append(song_helper(song))
    return songs

async def get_song_by_id(song_id: str):
    try:
        song = await songs_collection.find_one({"_id": ObjectId(song_id)})
        if song:
            return song_helper(song)
    except:
        pass
    return None

async def search_songs(query: str):
    songs = []
    # Basic regex search
    regex_query = {"$regex": query, "$options": "i"}
    async for song in songs_collection.find({
        "$or": [
            {"title": regex_query},
            {"artist": regex_query},
            {"album": regex_query}
        ]
    }):
        songs.append(song_helper(song))
    return songs


async def delete_song(song_id: str) -> bool:
    """Delete a song by ID"""
    try:
        result = await songs_collection.delete_one({"_id": ObjectId(song_id)})
        return result.deleted_count > 0
    except:
        return False


async def get_songs_paginated(page: int = 1, limit: int = 20) -> dict:
    """Get paginated songs, newest first"""
    skip = (page - 1) * limit
    total = await songs_collection.count_documents({})
    
    songs = []
    async for song in songs_collection.find().sort("_id", -1).skip(skip).limit(limit):
        songs.append(song_helper(song))
    
    return {
        "songs": songs,
        "page": page,
        "limit": limit,
        "total": total,
        "pages": (total + limit - 1) // limit if total > 0 else 1
    }


# ==================== Playlists Collection ====================
playlists_collection = db.get_collection("playlists")


def playlist_helper(playlist) -> dict:
    return {
        "id": str(playlist["_id"]),
        "name": playlist.get("name", "Untitled"),
        "songs": playlist.get("songs", []),
        "cover_art": playlist.get("cover_art"),
        "created_at": playlist.get("created_at"),
        "is_ai_generated": playlist.get("is_ai_generated", False),
    }


async def create_playlist(name: str, songs: list = None, cover_art: str = None, is_ai: bool = False) -> str:
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
    async for pl in playlists_collection.find().sort("created_at", -1).skip(skip).limit(limit):
        playlists.append(playlist_helper(pl))
    
    return {
        "playlists": playlists,
        "page": page,
        "total": total,
        "pages": (total + limit - 1) // limit if total > 0 else 1
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
            {"_id": ObjectId(playlist_id)},
            {"$addToSet": {"songs": song_id}}
        )
        return result.modified_count > 0
    except:
        return False


async def remove_song_from_playlist(playlist_id: str, song_id: str) -> bool:
    try:
        result = await playlists_collection.update_one(
            {"_id": ObjectId(playlist_id)},
            {"$pull": {"songs": song_id}}
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


# ==================== Play History Collection ====================
play_history_collection = db.get_collection("play_history")


async def record_play(song_id: str):
    """Record a song play"""
    from datetime import datetime
    await play_history_collection.insert_one({
        "song_id": song_id,
        "played_at": datetime.utcnow()
    })


async def get_recently_played(limit: int = 10) -> list:
    """Get recently played songs (unique, most recent first)"""
    from datetime import datetime, timedelta
    
    # Get plays from last 7 days
    since = datetime.utcnow() - timedelta(days=7)
    
    pipeline = [
        {"$match": {"played_at": {"$gte": since}}},
        {"$sort": {"played_at": -1}},
        {"$group": {"_id": "$song_id", "last_played": {"$first": "$played_at"}}},
        {"$sort": {"last_played": -1}},
        {"$limit": limit}
    ]
    
    song_ids = []
    async for doc in play_history_collection.aggregate(pipeline):
        song_ids.append(doc["_id"])
    
    # Fetch song details
    songs = []
    for sid in song_ids:
        song = await get_song_by_id(sid)
        if song:
            songs.append(song)
    
    return songs


# ==================== AI Cache Collection ====================
ai_cache_collection = db.get_collection("ai_cache")


async def get_ai_cache(cache_key: str = "home_recommendations") -> dict:
    """Get cached AI recommendations"""
    doc = await ai_cache_collection.find_one({"key": cache_key})
    if doc:
        return {
            "key": doc.get("key"),
            "recommendations": doc.get("recommendations", []),
            "ai_playlist_name": doc.get("ai_playlist_name", "AI Mix"),
            "ai_playlist_songs": doc.get("ai_playlist_songs", []),
            "updated_at": doc.get("updated_at"),
        }
    return None


async def update_ai_cache(
    recommendations: list,
    ai_playlist_name: str,
    ai_playlist_songs: list,
    cache_key: str = "home_recommendations"
):
    """Update AI recommendations cache"""
    from datetime import datetime
    await ai_cache_collection.update_one(
        {"key": cache_key},
        {"$set": {
            "key": cache_key,
            "recommendations": recommendations,
            "ai_playlist_name": ai_playlist_name,
            "ai_playlist_songs": ai_playlist_songs,
            "updated_at": datetime.utcnow(),
        }},
        upsert=True
    )



# ==================== YouTube Tasks Collection ====================
youtube_tasks_collection = db.get_collection("youtube_tasks")


def youtube_task_helper(task) -> dict:
    return {
        "id": str(task["_id"]),
        "task_id": task.get("task_id"),
        "url": task.get("url"),
        "status": task.get("status"),
        "progress": task.get("progress", 0),
        "title": task.get("title", ""),
        "artist": task.get("artist", ""),
        "thumbnail": task.get("thumbnail", ""),
        "duration": task.get("duration", 0),
        "file_size": task.get("file_size", 0),
        "error": task.get("error", ""),
        "quality": task.get("quality", "320"),
        "song_id": task.get("song_id"),
        "created_at": task.get("created_at"),
    }


async def save_youtube_task(task_data: dict) -> str:
    """Insert or update a YouTube download task"""
    task_id = task_data.get("task_id")
    existing = await youtube_tasks_collection.find_one({"task_id": task_id})
    
    if existing:
        await youtube_tasks_collection.update_one(
            {"task_id": task_id},
            {"$set": task_data}
        )
        return str(existing["_id"])
    else:
        from datetime import datetime
        task_data["created_at"] = datetime.utcnow()
        result = await youtube_tasks_collection.insert_one(task_data)
        return str(result.inserted_id)


async def get_youtube_task(task_id: str) -> dict:
    """Get a YouTube task by task_id"""
    task = await youtube_tasks_collection.find_one({"task_id": task_id})
    if task:
        return youtube_task_helper(task)
    return None


async def get_youtube_tasks(page: int = 1, limit: int = 10) -> dict:
    """Get paginated YouTube tasks, newest first"""
    skip = (page - 1) * limit
    total = await youtube_tasks_collection.count_documents({})
    
    tasks = []
    async for task in youtube_tasks_collection.find().sort("created_at", -1).skip(skip).limit(limit):
        tasks.append(youtube_task_helper(task))
    
    return {
        "tasks": tasks,
        "page": page,
        "limit": limit,
        "total": total,
        "pages": (total + limit - 1) // limit if total > 0 else 1
    }


async def update_youtube_task(task_id: str, updates: dict):
    """Update a YouTube task"""
    await youtube_tasks_collection.update_one(
        {"task_id": task_id},
        {"$set": updates}
    )


async def delete_youtube_task(task_id: str):
    """Delete a single YouTube task"""
    await youtube_tasks_collection.delete_one({"task_id": task_id})


async def clear_all_youtube_tasks():
    """Delete all YouTube tasks"""
    result = await youtube_tasks_collection.delete_many({})
    return result.deleted_count

