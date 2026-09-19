import re
from difflib import SequenceMatcher
from bson import ObjectId
from app.db.connection import songs_collection, albums_collection


# Bump when album_key_for grouping rules change: scans rebuild albums once
# when the stored version differs, then persist the new version.
GROUPING_VERSION = 3

# Placeholders that may be overwritten by enriched metadata — never let a
# placeholder clobber a real value on re-scans.
GENERIC_ALBUMS = {"", "Unknown Album", "Unknown", "Telegram", "Audio", None}
GENERIC_ARTISTS = {"", "Unknown Artist", "Unknown", None}

# Qualifiers that don't change *which* song it is — stripped for grouping so
# "Song (Official Video)", "Song - Lyric Video" and "song_hq" land together.
_GROUPING_NOISE = [
    "official music video",
    "official video",
    "official audio",
    "official lyric video",
    "official visualizer",
    "official",
    "music video",
    "lyric video",
    "lyrics video",
    "visualizer",
    "visualiser",
    "audio",
    "lyrics",
    "remastered",
    "remaster",
    "hq",
    "hd",
    "4k",
    "mv",
]


def normalize_text(value: str | None) -> str:
    if not value:
        return ""
    value = value.strip().lower()
    value = re.sub(r"\s+", " ", value)
    return value


def normalize_title_for_grouping(title: str | None) -> str:
    """Core song title used for grouping (display title is left untouched)."""
    if not title:
        return ""
    value = title.strip().lower()
    # strip file extension
    value = re.sub(r"\.(mp3|m4a|flac|wav|ogg|opus|aac|mp4|mkv|webm|avi|mov)$", "", value)
    # drop bracketed qualifiers: (official video), [hq], ...
    value = re.sub(r"\([^)]*\)", " ", value)
    value = re.sub(r"\[[^\]]*\]", " ", value)
    # separators -> space
    value = re.sub(r"[_.\-]+", " ", value)
    # drop noise words
    for noise in _GROUPING_NOISE:
        value = re.sub(rf"\b{re.escape(noise)}\b", " ", value)
    # drop leftover punctuation, collapse whitespace
    value = re.sub(r"[^a-z0-9 ]", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value


def normalize_artist_for_grouping(artist: str | None) -> str:
    """Normalize artist: handles 'Artist - Topic' (YouTube auto-channels) and VEVO."""
    if not artist:
        return ""
    value = artist.strip().lower()
    value = re.sub(r"\s*-\s*topic\s*$", "", value)
    value = re.sub(r"\bvevo\b", "", value)
    value = re.sub(r"[^a-z0-9 ]", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value or "unknown artist"


def album_key_for(title: str | None, artist: str | None, album: str | None) -> str:
    """Group 'same music names' together.

    Primary grouping: normalized album name if present and not generic,
    else normalized artist + core title (qualifiers like "official video",
    "[hq]", "- Topic" stripped) so duplicates/covers land together.
    Display titles are never modified — only the grouping key.
    """
    norm_album = normalize_text(album)
    # "Song - Single" collections are just the single itself; drop the suffix
    # so singles don't get odd album names.
    norm_album = re.sub(r"\s*-\s*single\s*$", "", norm_album)
    generic = {"", "unknown album", "unknown", "telegram", "audio"}
    if norm_album and norm_album not in generic:
        return f"album:{norm_album}"
    norm_artist = normalize_artist_for_grouping(artist)
    norm_title = normalize_title_for_grouping(title)
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
        "year": song.get("year"),
        "genre": song.get("genre"),
        "play_count": song.get("play_count", 0),
        "meta_checked": song.get("meta_checked", False),
        "meta_match": song.get("meta_match", False),
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
        # One DB row per Telegram message: partial unique index (only docs
        # with a positive int message id are covered, legacy rows ignored).
        await songs_collection.create_index(
            "telegram_message_id",
            unique=True,
            partialFilterExpression={"telegram_message_id": {"$gt": 0}},
        )
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
    year: int = None,
    genre: str = None,
    meta_checked: bool = None,
    meta_match: bool = None,
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
        # Never let a placeholder ("Unknown Album"/"Unknown Artist") clobber
        # a real enriched value on re-scans; specific values always win.
        if artist and (
            existing.get("artist") in GENERIC_ARTISTS or artist not in GENERIC_ARTISTS
        ):
            updates["artist"] = artist
        if album and (
            existing.get("album") in GENERIC_ALBUMS or album not in GENERIC_ALBUMS
        ):
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
        # Stable store metadata: fill when missing, never overwrite.
        if year and not existing.get("year"):
            updates["year"] = year
        if genre and not existing.get("genre"):
            updates["genre"] = genre
        if meta_checked is not None:
            updates["meta_checked"] = meta_checked
        if meta_match is not None:
            updates["meta_match"] = meta_match
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
        "year": year,
        "genre": genre,
        "play_count": 0,
        "meta_checked": meta_checked,
        "meta_match": meta_match,
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
    if not album_name or album_name in GENERIC_ALBUMS:
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
    """Regroup all songs into albums efficiently in-memory and bulk upsert."""
    await albums_collection.delete_many({})

    albums_map = {}
    songs_to_update = []

    async for song in songs_collection.find({}):
        title = song.get("title")
        artist = song.get("artist")
        album = song.get("album")
        raw_key = song.get("album_key") or album_key_for(title, artist, album)
        album_key = raw_key.casefold() if raw_key else "untitled"

        if song.get("album_key") != album_key:
            songs_to_update.append((song["_id"], album_key))

        album_name = album
        if not album_name or album_name in GENERIC_ALBUMS:
            album_name = title or "Untitled"
        cover = song.get("cover_art") or song.get("thumbnail")
        song_id = str(song["_id"])

        if album_key in albums_map:
            entry = albums_map[album_key]
            if song_id not in entry["song_ids"]:
                entry["song_ids"].append(song_id)
            if album_name and not entry.get("name"):
                entry["name"] = album_name
            if cover and not entry.get("cover_art"):
                entry["cover_art"] = cover
        else:
            albums_map[album_key] = {
                "album_key": album_key,
                "name": album_name,
                "artist": artist,
                "cover_art": cover,
                "song_ids": [song_id],
            }

    if songs_to_update:
        from pymongo import UpdateOne
        ops = [UpdateOne({"_id": sid}, {"$set": {"album_key": ak}}) for sid, ak in songs_to_update]
        for i in range(0, len(ops), 1000):
            await songs_collection.bulk_write(ops[i:i+1000])

    if albums_map:
        docs = list(albums_map.values())
        for i in range(0, len(docs), 1000):
            await albums_collection.insert_many(docs[i:i+1000])

    return len(albums_map)


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


async def get_song_by_telegram_id(message_id: int) -> dict | None:
    """Dedupe lookup: one DB row per Telegram message id."""
    try:
        doc = await songs_collection.find_one({"telegram_message_id": message_id})
        return song_helper(doc) if doc else None
    except Exception:
        return None


async def search_songs(query: str, limit: int = 50):
    """Fast path first: in-memory index (inverted postings + typo tolerance
    + personalized ranking). Falls back to Mongo regex + difflib when the
    index is unavailable, so search never hard-fails.
    """
    q = (query or "").strip()
    if not q:
        return []
    try:
        from app.db.crud.search_engine import get_engine

        engine = await get_engine()
        if engine.songs:
            return engine.search_songs(q, limit=limit)
    except Exception:
        pass
    return await _search_songs_mongo(q, limit)


async def _search_songs_mongo(query: str, limit: int = 50):
    """Substring search (regex-escaped) + typo-tolerant fuzzy fallback."""
    q = (query or "").strip()
    if not q:
        return []
    rx = {"$regex": re.escape(q), "$options": "i"}
    exact: list = []
    seen = set()
    async for song in songs_collection.find(
        {
            "$or": [
                {"title": rx},
                {"artist": rx},
                {"album": rx},
            ]
        }
    ).limit(limit):
        exact.append(song_helper(song))
        seen.add(str(song["_id"]))
    if len(exact) >= limit:
        return exact[:limit]
    # Fuzzy fill: score every remaining candidate, keep the best ones.
    scored: list[tuple[float, dict]] = []
    async for song in songs_collection.find(
        {},
        projection={
            "title": 1, "artist": 1, "album": 1, "play_count": 1,
            "duration": 1, "cover_art": 1, "thumbnail": 1,
            "file_name": 1, "has_video": 1, "s3_video_key": 1,
            "telegram_message_id": 1, "album_key": 1, "year": 1,
            "genre": 1,
        },
    ):
        sid = str(song["_id"])
        if sid in seen:
            continue
        score = _match_score(
            q, song.get("title"), song.get("artist"), song.get("album")
        )
        if score >= _FUZZY_THRESHOLD:
            scored.append((score, song))
    scored.sort(
        key=lambda t: (-t[0], -(t[1].get("play_count") or 0))
    )
    for _, song in scored[: max(0, limit - len(exact))]:
        exact.append(song_helper(song))
    return exact


# ------------------------- fuzzy matching helpers -------------------------

_FUZZY_THRESHOLD = 0.55


def _norm_search(value: str | None) -> str:
    """Lowercase alphanumeric normalization for fuzzy comparison."""
    if not value:
        return ""
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9 ]", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def _match_score(query: str, *fields: str | None) -> float:
    """0..1 relevance of a query against candidate text fields.

    Exact substring => 1.0. Otherwise the best of full-string similarity
    and per-token coverage, so both "shape of you" and "shap of yu"
    still match "Shape of You".
    """
    q = _norm_search(query)
    if not q:
        return 0.0
    norms = [_norm_search(f) for f in fields]
    norms = [n for n in norms if n]
    if not norms:
        return 0.0
    for n in norms:
        if q in n:
            return 1.0
    best = 0.0
    for n in norms:
        best = max(best, SequenceMatcher(None, q, n).ratio())
        # Long candidates dilute full-string ratio; also compare against a
        # sliding window of query length so "midnight" matches a long title.
        if len(n) > len(q) + 4 and len(q) >= 4:
            for i in range(0, len(n) - len(q) + 1):
                best = max(
                    best,
                    SequenceMatcher(None, q, n[i : i + len(q)]).ratio()
                    * 0.95,
                )
                if best >= 1.0:
                    return 1.0
    # Token coverage: every query word should resemble some candidate word.
    words = [w for n in norms for w in n.split()]
    qtokens = q.split()
    if words and qtokens:
        sims = [
            max(SequenceMatcher(None, qt, w).ratio() for w in words)
            for qt in qtokens
        ]
        best = max(best, sum(sims) / len(sims))
    return best


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
    # Deterministic track order (movie albums list A–Z).
    songs.sort(key=lambda s: (s.get("title") or "").casefold())
    return {
        "id": str(a["_id"]),
        "album_key": a.get("album_key"),
        "name": a.get("name"),
        "artist": a.get("artist"),
        "cover_art": a.get("cover_art"),
        "song_count": len(songs),
        "songs": songs,
    }


async def get_artists(page: int = 1, limit: int = 20, query: str = None) -> dict:
    """Artist directory: raw artist names merged by normalized key."""
    match = {"artist": {"$nin": [None, "", "Unknown Artist", "Unknown"]}}
    if query and query.strip():
        match["artist"] = {
            **match["artist"],
            "$regex": re.escape(query.strip()),
            "$options": "i",
        }
    pipeline = [
        {"$match": match},
        {
            "$group": {
                "_id": "$artist",
                "song_count": {"$sum": 1},
                "albums": {"$addToSet": "$album_key"},
                "total_plays": {"$sum": {"$ifNull": ["$play_count", 0]}},
            }
        },
    ]
    buckets: dict = {}
    async for doc in songs_collection.aggregate(pipeline):
        raw = doc["_id"] or ""
        key = normalize_artist_for_grouping(raw)
        b = buckets.setdefault(
            key, {"names": {}, "song_count": 0, "albums": set(), "total_plays": 0}
        )
        b["names"][raw] = b["names"].get(raw, 0) + doc.get("song_count", 0)
        b["song_count"] += doc.get("song_count", 0)
        b["total_plays"] += doc.get("total_plays", 0) or 0
        for ak in doc.get("albums", []) or []:
            if ak:
                b["albums"].add(ak)

    merged = []
    for key, b in buckets.items():
        display = max(b["names"].items(), key=lambda kv: kv[1])[0]
        merged.append(
            {
                "key": key,
                "name": display,
                "raw_names": sorted(b["names"]),
                "song_count": b["song_count"],
                "album_count": len(b["albums"]),
                "total_plays": b["total_plays"],
            }
        )
    merged.sort(key=lambda a: (-a["song_count"], a["name"].casefold()))
    total = len(merged)
    start = (page - 1) * limit
    page_items = merged[start : start + limit]
    # Cover: art from the most-played track that has any; fall back to an
    # artist-level store lookup so artists aren't blank when songs lack art.
    for item in page_items:
        cover = None
        async for s in songs_collection.find(
            {
                "artist": {"$in": item["raw_names"]},
                "cover_art": {"$nin": [None, ""]},
            }
        ).sort("play_count", -1).limit(1):
            cover = s.get("cover_art") or s.get("thumbnail")
        item["cover_art"] = cover
    missing = [item for item in page_items if not item["cover_art"]]
    if missing:
        import asyncio as _asyncio

        from app.services.artwork import fetch_artist_art as _artist_art

        arts = await _asyncio.gather(
            *[_artist_art(item["name"]) for item in missing],
            return_exceptions=True,
        )
        for item, art in zip(missing, arts):
            if isinstance(art, str) and art:
                item["cover_art"] = art
    for item in page_items:
        del item["raw_names"]
    return {
        "artists": page_items,
        "page": page,
        "limit": limit,
        "total": total,
        "pages": (total + limit - 1) // limit if total > 0 else 1,
    }


def _artist_song_sort_key(s: dict):
    """Played songs first (most plays first); unplayed by latest year/album."""
    plays = s.get("play_count", 0) or 0
    year = s.get("year") or 0
    return (
        plays == 0,
        -plays,
        -year,
        (s.get("album") or "").casefold(),
        (s.get("title") or "").casefold(),
    )


async def get_artist_detail(name: str) -> dict | None:
    """Artist profile: songs ordered by plays, then latest year/album."""
    key = normalize_artist_for_grouping(name)
    if not key or key == "unknown artist":
        return None
    try:
        raws = await songs_collection.distinct("artist")
    except Exception:
        return None
    variants = [r for r in raws if r and normalize_artist_for_grouping(r) == key]
    if not variants:
        return None
    songs = [
        song_helper(d)
        async for d in songs_collection.find({"artist": {"$in": variants}})
    ]
    if not songs:
        return None
    songs.sort(key=_artist_song_sort_key)

    from collections import Counter

    display = Counter(s.get("artist", "") for s in songs).most_common(1)[0][0]
    # Group by album_key (stable across naming variants), display the most
    # common album name. Include the album's DB id so clients can open it.
    albums_map: dict = {}
    for s in songs:
        akey = s.get("album_key") or f"name:{(s.get('album') or 'Unknown Album').casefold()}"
        a = albums_map.setdefault(
            akey,
            {"name": "", "names": Counter(), "year": 0, "cover_art": None, "song_count": 0},
        )
        a["names"][s.get("album") or "Unknown Album"] += 1
        a["song_count"] += 1
        if (s.get("year") or 0) > a["year"]:
            a["year"] = s.get("year")
        if not a["cover_art"] and s.get("cover_art"):
            a["cover_art"] = s.get("cover_art")
    albums = []
    for akey, a in albums_map.items():
        album_id = None
        try:
            doc = await albums_collection.find_one({"album_key": akey})
            if doc:
                album_id = str(doc["_id"])
                if not a["cover_art"]:
                    a["cover_art"] = doc.get("cover_art")
        except Exception:
            pass
        albums.append(
            {
                "id": album_id,
                "name": a["names"].most_common(1)[0][0],
                "year": a["year"] or None,
                "cover_art": a["cover_art"],
                "song_count": a["song_count"],
            }
        )
    albums.sort(key=lambda a: (-(a["year"] or 0), (a["name"] or "").casefold()))
    cover = next((s.get("cover_art") for s in songs if s.get("cover_art")), None)
    if not cover:
        try:
            from app.services.artwork import fetch_artist_art as _artist_art

            cover = await _artist_art(display)
        except Exception:
            cover = None
    return {
        "key": key,
        "name": display,
        "cover_art": cover,
        "song_count": len(songs),
        "album_count": len(albums),
        "total_plays": sum(s.get("play_count", 0) or 0 for s in songs),
        "songs": songs,
        "albums": albums,
    }


async def search_library(
    query: str, song_limit: int = 8, album_limit: int = 8, artist_limit: int = 8
) -> dict:
    """Unified search across songs, albums and artists (typo-tolerant)."""
    q = (query or "").strip()
    if not q:
        return {"songs": [], "albums": [], "artists": []}
    song_limit = max(1, min(song_limit, 50))
    album_limit = max(1, min(album_limit, 50))
    artist_limit = max(1, min(artist_limit, 50))
    songs = await search_songs(q, limit=song_limit)
    # Fast path: albums + artists from the in-memory index (no extra
    # queries, no cover-API calls). Falls through to Mongo on any failure.
    try:
        from app.db.crud.search_engine import get_engine

        engine = await get_engine()
        if engine.songs:
            return {
                "songs": songs[:song_limit],
                "albums": engine.search_albums(q, limit=album_limit),
                "artists": engine.search_artists(q, limit=artist_limit),
            }
    except Exception:
        pass
    rx = {"$regex": re.escape(q), "$options": "i"}
    albums = []
    seen_albums = set()
    async for a in albums_collection.find(
        {"$or": [{"name": rx}, {"artist": rx}]}
    ).limit(album_limit):
        seen_albums.add(str(a["_id"]))
        albums.append(
            {
                "id": str(a["_id"]),
                "name": a.get("name"),
                "artist": a.get("artist"),
                "cover_art": a.get("cover_art"),
                "song_count": len(a.get("song_ids", []) or []),
            }
        )
    if len(albums) < album_limit:
        # Fuzzy fill for albums with typos in the query.
        scored: list[tuple[float, dict]] = []
        async for a in albums_collection.find(
            {}, projection={"name": 1, "artist": 1, "cover_art": 1, "song_ids": 1}
        ):
            if str(a["_id"]) in seen_albums:
                continue
            score = _match_score(q, a.get("name"), a.get("artist"))
            if score >= _FUZZY_THRESHOLD:
                scored.append((score, a))
        scored.sort(key=lambda t: -t[0])
        for _, a in scored[: album_limit - len(albums)]:
            albums.append(
                {
                    "id": str(a["_id"]),
                    "name": a.get("name"),
                    "artist": a.get("artist"),
                    "cover_art": a.get("cover_art"),
                    "song_count": len(a.get("song_ids", []) or []),
                }
            )
    artists = (await get_artists(page=1, limit=artist_limit, query=q))["artists"]
    if len(artists) < artist_limit:
        # Fuzzy fill for artists: score the full directory (cheap, grouped).
        have = {a.get("key") for a in artists}
        all_artists = (await get_artists(page=1, limit=500))["artists"]
        scored_names: list[tuple[float, dict]] = []
        for a in all_artists:
            if a.get("key") in have:
                continue
            score = _match_score(q, a.get("name"))
            if score >= _FUZZY_THRESHOLD:
                scored_names.append((score, a))
        scored_names.sort(key=lambda t: -t[0])
        artists = artists + [a for _, a in scored_names[: artist_limit - len(artists)]]
    return {"songs": songs[:song_limit], "albums": albums, "artists": artists}


async def suggest_library(query: str, limit: int = 6) -> dict:
    """Minimal autocomplete payload for as-you-type search."""
    q = (query or "").strip()
    if not q:
        return {"songs": [], "albums": [], "artists": []}
    try:
        from app.db.crud.search_engine import get_engine

        engine = await get_engine()
        if engine.songs:
            return engine.suggest(q, limit=limit)
    except Exception:
        pass
    songs = await search_songs(q, limit=limit)
    return {
        "songs": [
            {"id": s.get("id"), "title": s.get("title"), "artist": s.get("artist")}
            for s in songs
        ],
        "albums": [],
        "artists": [],
    }
