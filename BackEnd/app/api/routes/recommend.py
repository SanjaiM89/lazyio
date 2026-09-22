from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel

from app.db.crud.songs import get_song_by_id, search_songs, get_all_songs
from app.db.crud.likes import like_song, dislike_song, get_like_status, get_liked_songs
from app.db.crud.history import get_recently_played
from app.db.crud.ai_queue import (
    get_ai_queue,
    save_ai_queue,
    mark_song_played as db_mark_played,
    get_queue_songs,
    refill_queue_if_needed,
    clear_played_queue,
)
from app.db.crud.app_playlists import (
    get_app_playlists,
    get_playlist_with_songs,
    create_app_playlist,
)
from app.services.reco import get_hybrid_similar
from app.ai.mistral import (
    get_music_recommendations,
    get_recommendations,
    get_homepage_recommendations,
)
from app.db.crud.ai_cache import get_ai_cache, update_ai_cache

router = APIRouter(tags=["recommend"])


@router.get("/api/home")
async def api_home():
    """Homepage payload expected by web + Flutter clients."""
    recently = await get_recently_played(limit=5)
    cache = await get_ai_cache()
    ai_name = "AI Mix"
    ai_songs = []
    recommendations = []
    last_updated = None
    if cache:
        ai_name = cache.get("ai_playlist_name", ai_name)
        recommendations = cache.get("recommendations", [])
        last_updated = cache.get("updated_at")
        for sid in cache.get("ai_playlist_songs", []):
            song = await get_song_by_id(sid)
            if song:
                ai_songs.append(song)
    return {
        "recently_played": recently,
        "ai_playlist": {"name": ai_name, "songs": ai_songs},
        "recommendations": recommendations,
        "last_updated": str(last_updated) if last_updated else None,
    }


async def _refresh_homepage_cache():
    all_songs = await get_all_songs()
    if not all_songs:
        return
    liked_songs = await get_liked_songs()
    result = await get_homepage_recommendations(all_songs, liked_songs)
    await update_ai_cache(
        recommendations=result["recommendations"],
        ai_playlist_name=result["ai_playlist"]["name"],
        ai_playlist_songs=result["ai_playlist"]["song_ids"],
    )


@router.post("/api/home/refresh")
async def api_home_refresh(background_tasks: BackgroundTasks):
    background_tasks.add_task(_refresh_homepage_cache)
    return {"status": "started"}


@router.post("/api/recommend")
async def recommend(current_song_id: str, history_ids: list[str]):
    current_song = await get_song_by_id(current_song_id)
    history = []
    for hid in history_ids:
        s = await get_song_by_id(hid)
        if s:
            history.append(s)

    if not current_song:
        return {"recommendations": []}

    all_songs = await get_all_songs()
    recs = await get_music_recommendations(current_song, history, all_songs)

    db_matches = []
    for rec in recs:
        parts = rec.split("-")
        if len(parts) >= 1:
            query = parts[0].strip()
            matches = await search_songs(query)
            if matches:
                db_matches.extend(matches)

    unique_matches = {v["id"]: v for v in db_matches}.values()
    return {"mistral_suggestions": recs, "playable_matches": list(unique_matches)}


@router.post("/api/admin/scan-audio-features")
async def api_scan_audio_features(background_tasks: BackgroundTasks):
    return {
        "status": "started",
        "message": "Scan functionality requires persistent local storage or temporary download logic.",
    }


@router.get("/api/recommend/similar/{song_id}")
async def api_recommend_similar(song_id: str, limit: int = 10,
                                same_language: bool = True,
                                explain: bool = False):
    """Hybrid recommendations: FAISS audio similarity (content) blended
    with next-track co-occurrence (behavior), plus affinity boosts.

    Falls back to pure content-based results for cold-start tracks.
    """
    from app.db.crud.profile import get_profile

    profile = await get_profile()
    songs = await get_hybrid_similar(
        song_id, limit=max(1, min(limit, 50)), same_language=same_language,
        affinity={"languages": profile.get("languages", {}),
                  "genres": profile.get("genres", {})},
    )
    if not explain:
        songs = [{k: v for k, v in s.items() if k != "reco_score"} for s in songs]
    # `similar_songs` is the historic key; `similar`/`songs` aliases keep
    # the Qt desktop client (which reads those keys) working.
    return {"similar_songs": songs, "similar": songs, "songs": songs}


@router.post("/api/songs/{song_id}/like")
async def api_like_song(song_id: str):
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    await like_song(song_id)
    return {"status": "liked", "song_id": song_id}


@router.post("/api/songs/{song_id}/dislike")
async def api_dislike_song(song_id: str):
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    await dislike_song(song_id)
    return {"status": "disliked", "song_id": song_id}


@router.get("/api/songs/{song_id}/like-status")
async def api_get_like_status(song_id: str):
    status = await get_like_status(song_id)
    return status


@router.get("/api/recommendations")
async def api_get_recommendations(limit: int = 10):
    recs = await get_recommendations(limit)
    return {"recommendations": recs}


@router.get("/api/liked-songs")
async def api_get_liked_songs():
    songs = await get_liked_songs()
    return {"songs": songs}


@router.get("/api/upcoming-queue/{song_id}")
async def api_get_upcoming_queue(song_id: str):
    current_song = await get_song_by_id(song_id)
    if not current_song:
        raise HTTPException(status_code=404, detail="Song not found")

    liked_songs = await get_liked_songs()
    all_songs = await get_all_songs()

    history = liked_songs[:5] if liked_songs else all_songs[:5]
    ai_suggestions = await get_music_recommendations(current_song, history, all_songs)

    matches = []
    for suggestion in ai_suggestions:
        parts = suggestion.split(" - ")
        if len(parts) >= 1:
            query = parts[0].strip()
            found = await search_songs(query)
            for s in found:
                if s["id"] != song_id and s["id"] not in [m["id"] for m in matches]:
                    matches.append(s)
                    break

    if len(matches) < 5:
        liked_ids = {m["id"] for m in matches}
        liked_ids.add(song_id)
        for s in liked_songs:
            if s["id"] not in liked_ids:
                matches.append(s)
                liked_ids.add(s["id"])
            if len(matches) >= 10:
                break

    return {"ai_suggestions": ai_suggestions, "queue": matches[:10]}


@router.get("/api/ai-queue")
async def api_get_ai_queue():
    await refill_queue_if_needed(min_songs=10)
    queue_data = await get_ai_queue()
    songs = await get_queue_songs()
    return {
        "songs": songs,
        "played_count": len(queue_data["played_ids"]),
        "created_at": (
            str(queue_data["created_at"]) if queue_data["created_at"] else None
        ),
        "updated_at": (
            str(queue_data["updated_at"]) if queue_data["updated_at"] else None
        ),
    }


@router.post("/api/ai-queue/refresh")
async def api_refresh_ai_queue():
    liked_songs = await get_liked_songs()
    all_songs = await get_all_songs()

    if not all_songs:
        return {"status": "error", "message": "No songs in library"}

    history = liked_songs[:5] if liked_songs else all_songs[:5]
    import random

    sample_song = (
        random.choice(liked_songs) if liked_songs else random.choice(all_songs)
    )

    ai_suggestions = await get_music_recommendations(sample_song, history, all_songs)

    matched_ids = []
    for suggestion in ai_suggestions:
        parts = suggestion.split(" - ")
        if parts:
            query = parts[0].strip()
            found = await search_songs(query)
            for s in found:
                if s["id"] not in matched_ids:
                    matched_ids.append(s["id"])
                    break

    for s in liked_songs:
        if s["id"] not in matched_ids:
            matched_ids.append(s["id"])
        if len(matched_ids) >= 15:
            break

    if len(matched_ids) < 10:
        random.shuffle(all_songs)
        for s in all_songs:
            if s["id"] not in matched_ids:
                matched_ids.append(s["id"])
            if len(matched_ids) >= 15:
                break

    await clear_played_queue()
    await save_ai_queue(matched_ids)

    songs = await get_queue_songs()

    return {
        "status": "refreshed",
        "count": len(songs),
        "songs": songs,
        "ai_suggestions": ai_suggestions,
    }


@router.post("/api/ai-queue/mark-played/{song_id}")
async def api_mark_song_played(song_id: str):
    await db_mark_played(song_id)
    await refill_queue_if_needed(min_songs=10)
    return {"status": "marked", "song_id": song_id}


class SignalRequest(BaseModel):
    signal_type: str
    duration_seconds: int = 0


@router.post("/api/ai-queue/signal/{song_id}")
async def api_queue_signal(song_id: str, request: SignalRequest):
    from app.db.crud.profile import update_affinity

    signal_type = request.signal_type
    duration = request.duration_seconds

    song = await get_song_by_id(song_id)
    if not song:
        return {"status": "error", "message": "Song not found"}

    if signal_type == "listen" and duration >= 60:
        await db_mark_played(song_id)
    elif signal_type == "skip":
        await db_mark_played(song_id)
        await update_affinity(song_id, -0.5)
    elif signal_type == "like":
        await like_song(song_id)
        await update_affinity(song_id, 2.0)
    elif signal_type == "dislike":
        await dislike_song(song_id)
        await db_mark_played(song_id)
        await update_affinity(song_id, -2.0)
    if signal_type == "listen":
        from app.db.crud.profile import weight_for_completion

        try:
            total = float(song.get("duration") or 0)
            pct = (duration / total) if total > 0 else (1.0 if duration >= 60 else 0.0)
            await update_affinity(song_id, weight_for_completion(pct))
        except Exception:
            pass

    await refill_queue_if_needed(min_songs=10)
    return {"status": "processed", "signal": signal_type, "song_id": song_id}


@router.get("/api/app-playlists")
async def api_get_app_playlists():
    return await get_app_playlists()


@router.get("/api/app-playlists/{playlist_id}")
async def api_get_app_playlist(playlist_id: str):
    playlist = await get_playlist_with_songs(playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    return playlist


class GeneratePlaylistRequest(BaseModel):
    name: str = "New Mix"

@router.post("/api/app-playlists/generate")
async def api_generate_app_playlist(request: GeneratePlaylistRequest):
    all_songs = await get_all_songs()
    if not all_songs:
        raise HTTPException(status_code=400, detail="No songs in library")

    import random

    count = min(15, len(all_songs))
    selected = random.sample(all_songs, count)

    song_ids = [s["id"] for s in selected]
    playlist_id = await create_app_playlist(
        name=request.name, song_ids=song_ids, description="Generated playlist"
    )

    return {"status": "created", "id": playlist_id, "count": len(song_ids)}


@router.get("/api/profile")
async def api_get_profile():
    """Taste profile: language/genre affinities, highest first."""
    from app.db.crud.profile import get_profile

    profile = await get_profile()
    langs = sorted(profile.get("languages", {}).items(), key=lambda kv: -kv[1])
    genres = sorted(profile.get("genres", {}).items(), key=lambda kv: -kv[1])
    return {
        "languages": [{"name": k, "weight": v} for k, v in langs],
        "genres": [{"name": k, "weight": v} for k, v in genres],
        "updated_at": str(profile.get("updated_at")) if profile.get("updated_at") else None,
    }


class DecayRequest(BaseModel):
    rate: float = 0.9


@router.post("/api/admin/decay-profiles")
async def api_decay_profiles(request: DecayRequest):
    """Manually run taste decay (the weekly job does this automatically)."""
    from app.db.crud.profile import decay_profiles

    rate = max(0.0, min(1.0, float(request.rate)))
    modified = await decay_profiles(rate)
    return {"status": "decayed", "rate": rate, "profiles_touched": modified}
