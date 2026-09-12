import re
from bson import ObjectId
from app.db.connection import songs_collection, albums_collection


def normalize_text(value: str | None) -> str:
    if not value:
        return ""
    value = value.strip().lower()
    # remove bracketed extras like (official video), [hq], etc.? keep simple
    value = re.sub(r"\s+", " ", value)
    return value


def album_key_for(title: str | None, artist: str | None, album: str | None) -> str:
    """Group 'same music names' together.

    Primary grouping: normalized album name if present and not generic,
    else normalized 'artist - title' so covers/duplicates land together.
    """
    norm_album = normalize_text(album)
    generic = {"", "unknown album", "unknown", "telegram", "audio"}
    if norm_album and norm_album not in generic:
        return f"album:{norm_album}"
    norm_artist = normalize_text(artist)
    norm_title = normalize_text(title)
    # strip file extension from title for grouping
    norm_title = re.sub(r"\.(mp3|m4a|flac|wav|ogg|mp4|mkv|webm)$", "", norm_title)
    return f"track:{norm_artist}|{norm_title}"


def song_helper(song) -> dict:
    file_name = song.get("file_name", "")
    has_video = song.get("has_video", song.get("s3_video_key") is not None)
    telegram_message_id = song.get("telegram_message_id")

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
        "telegram_message_id": telegram_message_id,
        # legacy fields kept for backward compat with older clients
        "audio_telegram_id": telegram_message_id,
        "video_telegram_id": telegram_message_id if has_video else None,
        "s3_audio_key": song.get("s3_audio_key"),
        "s3_video_key": song.get("s3_video_key"),
        "has_video": has_video,
        "title": song.get("title"),
        "artist": song.get("artist"),
        "album": song.get("album"),
        "album_key": song.get("album_key"),
        "duration": song.get("duration"),
        "cover_art": song.get("cover_art") or song.get("thumbnail"),
        "thumbnail": song.get("thumbnail"),
        "file_name": file_name,
        "file_size": song.get("file_size"),
        "mime_type": song.get("mime_type"),
        "media_type": media_type,
        "source_channel": song.get("source_channel"),
    }


async def ensure_song_indexes():
    try:
        await songs_collection.create_index("telegram_message_id", unique=False)
    except Exception:
        pass
    try:
        await songs_collection.create_index("album_key")
    except Exception:
        pass
    try:
        await songs_collection.create_index(
            [("title", "text"), ("artist", "text"), ("album", "text")]
        )
    except Exception:
        pass
    try:
        await albums_collection.create_index("album_key", unique=True)
    except Exception:
        pass


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
    telegram_message_id: int = None,
    mime_type: str = None,
    source_channel: str = None,
):
    # Dedupe: prefer telegram id, else file/title match
    existing = None
    if telegram_message_id is not None:
        existing = await songs_collection.find_one(
            {"telegram_message_id": telegram_message_id}
        )
    if not existing:
        existing = await songs_collection.find_one(
            {"$or": [{"file_name": file_name}, {"title": title, "artist": artist}]}
        )
    album_key = album_key_for(title, artist, album)
    if existing:
        updates = {"album_key": album_key}
        if s3_audio_key:
            updates["s3_audio_key"] = s3_audio_key
        if s3_video_key:
            updates["s3_video_key"] = s3_video_key
            updates["has_video"] = True
        if telegram_message_id is not None:
            updates["telegram_message_id"] = telegram_message_id
        if title:
            updates["title"] = title
        if artist:
            updates["artist"] = artist
        if album:
            updates["album"] = album
        if duration:
            updates["duration"] = duration
        if cover_art:
            updates["cover_art"] = cover_art
        if thumbnail:
            updates["thumbnail"] = thumbnail
        if file_name:
            updates["file_name"] = file_name
        if file_size:
            updates["file_size"] = file_size
        if mime_type:
            updates["mime_type"] = mime_type
        if source_channel:
            updates["source_channel"] = source_channel
        if has_video:
            updates["has_video"] = True
        await songs_collection.update_one({"_id": existing["_id"]}, {"$set": updates})
        await upsert_album_for_song({**existing, **updates})
        return str(existing["_id"])

    song_data = {
        "telegram_message_id": telegram_message_id,
        "s3_audio_key": s3_audio_key,
        "s3_video_key": s3_video_key,
        "has_video": has_video or (s3_video_key is not None),
        "title": title,
        "artist": artist,
        "album": album,
        "album_key": album_key,
        "duration": duration,
        "cover_art": cover_art,
        "thumbnail": thumbnail or cover_art,
        "file_name": file_name,
        "file_size": file_size,
        "mime_type": mime_type,
        "source_channel": source_channel,
    }
    new_song = await songs_collection.insert_one(song_data)
    await upsert_album_for_song({**song_data, "_id": new_song.inserted_id})
    return str(new_song.inserted_id)


async def upsert_album_for_song(song: dict):
    """Maintain albums collection grouped by album_key."""
    album_key = song.get("album_key") or album_key_for(
        song.get("title"), song.get("artist"), song.get("album")
    )
    album_name = song.get("album")
    generic = {"", "Unknown Album", "Unknown", None}
    if not album_name or album_name in generic:
        # derive display name from title grouping
        album_name = song.get("title") or "Untitled"
    cover = song.get("cover_art") or song.get("thumbnail")
    song_id = str(song["_id"]) if song.get("_id") else None
    existing = await albums_collection.find_one({"album_key": album_key})
    if existing:
        updates = {}
        if album_name and not existing.get("name"):
            updates["name"] = album_name
        if cover and not existing.get("cover_art"):
            updates["cover_art"] = cover
        if song_id:
            await albums_collection.update_one(
                {"_id": existing["_id"]},
                {
                    "$addToSet": {"song_ids": song_id},
                    **({"$set": updates} if updates else {}),
                },
            )
        return str(existing["_id"])
    doc = {
        "album_key": album_key,
        "name": album_name,
        "artist": song.get("artist"),
        "cover_art": cover,
        "song_ids": [song_id] if song_id else [],
    }
    res = await albums_collection.insert_one(doc)
    return str(res.inserted_id)


async def rebuild_albums():
    """Regroup all songs into albums. Used after channel scans."""
    await albums_collection.delete_many({})
    count = 0
    async for song in songs_collection.find({}):
        album_key = song.get("album_key") or album_key_for(
            song.get("title"), song.get("artist"), song.get("album")
        )
        if song.get("album_key") != album_key:
            await songs_collection.update_one(
                {"_id": song["_id"]}, {"$set": {"album_key": album_key}}
            )
            song["album_key"] = album_key
        await upsert_album_for_song(song)
        count += 1
    return count


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
    except Exception:
        pass
    return None


async def get_song_raw_by_id(song_id: str):
    try:
        return await songs_collection.find_one({"_id": ObjectId(song_id)})
    except Exception:
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
        raw = await get_song_raw_by_id(song_id)
        result = await songs_collection.delete_one({"_id": ObjectId(song_id)})
        if raw and raw.get("album_key"):
            # remove from album, delete album if empty
            await albums_collection.update_many(
                {"album_key": raw["album_key"]}, {"$pull": {"song_ids": song_id}}
            )
            await albums_collection.delete_many({"song_ids": {"$size": 0}})
        return result.deleted_count > 0
    except Exception:
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


async def get_albums_paginated(page: int = 1, limit: int = 20) -> dict:
    skip = (page - 1) * limit
    total = await albums_collection.count_documents({})
    albums = []
    async for a in albums_collection.find().sort("_id", -1).skip(skip).limit(limit):
        albums.append(
            {
                "id": str(a["_id"]),
                "album_key": a.get("album_key"),
                "name": a.get("name"),
                "artist": a.get("artist"),
                "cover_art": a.get("cover_art"),
                "song_count": len(a.get("song_ids", [])),
                "song_ids": a.get("song_ids", []),
            }
        )
    return {
        "albums": albums,
        "page": page,
        "limit": limit,
        "total": total,
        "pages": (total + limit - 1) // limit if total > 0 else 1,
    }


async def get_album_with_songs(album_id: str) -> dict | None:
    try:
        a = await albums_collection.find_one({"_id": ObjectId(album_id)})
    except Exception:
        return None
    if not a:
        return None
    songs = []
    for sid in a.get("song_ids", []):
        s = await get_song_by_id(sid)
        if s:
            songs.append(s)
    return {
        "id": str(a["_id"]),
        "album_key": a.get("album_key"),
        "name": a.get("name"),
        "artist": a.get("artist"),
        "cover_art": a.get("cover_art"),
        "song_count": len(songs),
        "songs": songs,
    }
