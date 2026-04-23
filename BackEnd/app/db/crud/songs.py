from bson import ObjectId
from app.db.connection import songs_collection


def song_helper(song) -> dict:
    file_name = song.get("file_name", "")
    has_video = song.get("has_video", song.get("s3_video_key") is not None)

    if has_video:
        media_type = "video"
    else:
        video_exts = [".mp4", ".mkv", ".webm", ".avi", ".mov"]
        media_type = (
            "video"
            if any(file_name.lower().endswith(ext) for ext in video_exts)
            else "audio"
        )

    return {
        "id": str(song["_id"]),
        "s3_audio_key": song.get("s3_audio_key"),
        "s3_video_key": song.get("s3_video_key"),
        "has_video": has_video,
        "title": song.get("title"),
        "artist": song.get("artist"),
        "album": song.get("album"),
        "duration": song.get("duration"),
        "cover_art": song.get("cover_art") or song.get("thumbnail"),
        "thumbnail": song.get("thumbnail"),
        "file_name": file_name,
        "file_size": song.get("file_size"),
        "media_type": media_type,
    }


async def add_song(
    title: str = None,
    artist: str = None,
    album: str = None,
    duration: int = None,
    cover_art: str = None,
    file_name: str = None,
    file_size: int = None,
    thumbnail: str = None,
    s3_audio_key: str = None,
    s3_video_key: str = None,
    has_video: bool = False,
):
    existing = await songs_collection.find_one(
        {"$or": [{"file_name": file_name}, {"title": title, "artist": artist}]}
    )
    if existing:
        updates = {}
        if s3_audio_key:
            updates["s3_audio_key"] = s3_audio_key
        if s3_video_key:
            updates["s3_video_key"] = s3_video_key
            updates["has_video"] = True
        if updates:
            await songs_collection.update_one(
                {"_id": existing["_id"]}, {"$set": updates}
            )
        return str(existing["_id"])

    song_data = {
        "s3_audio_key": s3_audio_key,
        "s3_video_key": s3_video_key,
        "has_video": has_video or (s3_video_key is not None),
        "title": title,
        "artist": artist,
        "album": album,
        "duration": duration,
        "cover_art": cover_art,
        "thumbnail": thumbnail or cover_art,
        "file_name": file_name,
        "file_size": file_size,
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
    regex_query = {"$regex": query, "$options": "i"}
    async for song in songs_collection.find(
        {
            "$or": [
                {"title": regex_query},
                {"artist": regex_query},
                {"album": regex_query},
            ]
        }
    ):
        songs.append(song_helper(song))
    return songs


async def get_all_vectors() -> dict:
    vectors = {}
    async for song in songs_collection.find({"audio_features": {"$exists": True}}):
        if song.get("audio_features"):
            vectors[str(song["_id"])] = song["audio_features"]
    return vectors


async def update_song_features(song_id: str, features: list):
    await songs_collection.update_one(
        {"_id": ObjectId(song_id)}, {"$set": {"audio_features": features}}
    )


async def delete_song(song_id: str) -> bool:
    try:
        result = await songs_collection.delete_one({"_id": ObjectId(song_id)})
        return result.deleted_count > 0
    except:
        return False


async def get_songs_paginated(page: int = 1, limit: int = 20) -> dict:
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
        "pages": (total + limit - 1) // limit if total > 0 else 1,
    }


async def update_song_video(song_id: str, s3_video_key: str):
    if not song_id or not s3_video_key:
        return False
    try:
        result = await songs_collection.update_one(
            {"_id": ObjectId(song_id)},
            {
                "$set": {
                    "s3_video_key": s3_video_key,
                    "has_video": True,
                    "media_type": "video",
                }
            },
        )
        return result.modified_count > 0
    except Exception:
        return False
