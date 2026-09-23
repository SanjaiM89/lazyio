from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel

from app.db.crud.songs import get_song_by_id, set_song_language
from app.services.analysis_jobs import analyze_library_job, detect_library_languages
from app.services.language import normalize_language

router = APIRouter(tags=["analysis"])


class AnalyzeLibraryRequest(BaseModel):
    limit: int = 50
    force: bool = False
    max_mb: int = 150
    vocal: bool = True
    vocal_threshold: float = 0.2


@router.post("/api/admin/analyze-library")
async def api_analyze_library(request: AnalyzeLibraryRequest, background_tasks: BackgroundTasks):
    """Backfill Spotify-style audio descriptors (bpm, instrumentalness,
    lo-fi, energy, valence) + FAISS vectors for the library.

    Prefers fully cached files; otherwise streams a bounded prefix from
    Telegram. Runs in the background; poll per-song
    ``GET /api/songs/{id}/analysis`` for progress.
    """
    background_tasks.add_task(
        analyze_library_job,
        limit=max(1, min(request.limit, 500)),
        force=request.force,
        max_mb=max(10, min(request.max_mb, 2000)),
        vocal=request.vocal,
        vocal_threshold=request.vocal_threshold,
    )
    return {"status": "started"}


@router.get("/api/songs/{song_id}/analysis")
async def api_song_analysis(song_id: str):
    """Per-song audio descriptors + analyzer version."""
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    audio = song.get("audio") or {}
    return {"analyzed": bool(audio), "audio": audio}


class DetectLanguagesRequest(BaseModel):
    limit: int = 500
    force: bool = False

@router.post("/api/admin/detect-languages")
async def api_detect_languages(request: DetectLanguagesRequest, background_tasks: BackgroundTasks):
    """Fast metadata-only backfill of song languages (no audio needed)."""
    background_tasks.add_task(
        detect_library_languages,
        limit=max(1, min(request.limit, 5000)),
        force=request.force,
    )
    return {"status": "started"}


class SetLanguageRequest(BaseModel):
    language: str | None = None


@router.patch("/api/songs/{song_id}/language")
async def api_set_song_language(song_id: str, request: SetLanguageRequest):
    """Manually correct a song's language (null clears back to auto)."""
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    if request.language is not None and not normalize_language(request.language):
        raise HTTPException(status_code=400, detail="Unknown language")
    if request.language is None:
        from app.services.language import detect_language

        lang, _ = detect_language(song.get("title"), song.get("artist"), song.get("album"))
        await set_song_language(song_id, lang, source="auto")
    else:
        await set_song_language(song_id, request.language, source="manual")
    updated = await get_song_by_id(song_id)
    return {"id": song_id, "language": updated.get("language"),
            "language_source": updated.get("language_source")}


@router.get("/api/admin/language-stats")
async def api_language_stats():
    """Labeling coverage: total songs, labeled/unlabeled, per-language."""
    from app.db.connection import songs_collection

    total = await songs_collection.count_documents({})
    pipeline = [
        {"$group": {
            "_id": {"$ifNull": ["$language", None]},
            "count": {"$sum": 1},
        }},
        {"$sort": {"count": -1}},
    ]
    by_language = []
    labeled = 0
    async for doc in songs_collection.aggregate(pipeline):
        name = doc["_id"] or "unlabeled"
        by_language.append({"name": name, "count": doc["count"]})
        if doc["_id"]:
            labeled += doc["count"]
    return {"total": total, "labeled": labeled,
            "unlabeled": total - labeled, "by_language": by_language}


class SpreadLanguagesRequest(BaseModel):
    min_votes: int = 3
    agreement: float = 0.7


@router.post("/api/admin/spread-languages")
async def api_spread_languages(request: SpreadLanguagesRequest, background_tasks: BackgroundTasks):
    """Propagate language labels along co-listening edges (Step 3)."""
    from app.services.reco import spread_languages

    background_tasks.add_task(
        spread_languages,
        min_votes=max(2, request.min_votes),
        agreement=max(0.5, min(1.0, request.agreement)),
    )
    return {"status": "started"}
