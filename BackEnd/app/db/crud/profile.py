"""Single-user taste profile: language/genre affinities (Phase 4).

Lazyio is self-hosted and single-user, so one ``user_profile`` document
(``_id: "default"``) holds the whole taste model::

    {"languages": {"Tamil": 45.5, ...}, "genres": {"Kollywood": 38.0, ...}}

Engagement updates arrive from the signals endpoint
(``POST /api/ai-queue/signal/{song_id}``): completions push weights up,
skips push them down (clamped at zero). A weekly decay job
(``decay_profiles``) multiplies everything by ``rate`` so recent taste
outweighs ancient history.
"""

from datetime import datetime, timezone

from app.db.connection import Database

profile_collection = Database.get_collection("user_profile")

PROFILE_ID = "default"


def weight_for_completion(pct: float) -> float:
    """Engagement weight from fraction of the track played.

    Completion (>= 80%) rewards, early skips (<= 20%) penalize,
    passive middle listening counts a little.
    """
    try:
        pct = float(pct)
    except (TypeError, ValueError):
        return 0.0
    if pct >= 0.8:
        return 1.0
    if pct <= 0.2:
        return -0.5
    return 0.2


async def get_profile() -> dict:
    """Full profile doc, with empty affinity maps when new."""
    try:
        doc = await profile_collection.find_one({"_id": PROFILE_ID})
    except Exception:
        doc = None
    if not doc:
        return {"languages": {}, "genres": {}, "updated_at": None}
    return {
        "languages": doc.get("languages", {}) or {},
        "genres": doc.get("genres", {}) or {},
        "updated_at": doc.get("updated_at"),
    }


async def update_affinity(song_id: str, weight_change: float) -> bool:
    """Nudge language/genre affinities from one engagement event."""
    from app.db.crud.songs import get_song_raw_by_id
    from app.services.language import normalize_language

    try:
        raw = await get_song_raw_by_id(song_id)
    except Exception:
        raw = None
    if not raw:
        return False
    lang = normalize_language((raw.get("language") or ""))
    genre = (raw.get("genre") or "").strip()
    if not lang and not genre:
        return False
    inc = {}
    if lang:
        inc[f"languages.{lang}"] = float(weight_change)
    if genre:
        inc[f"genres.{genre}"] = float(weight_change)
    try:
        await profile_collection.update_one(
            {"_id": PROFILE_ID},
            {
                "$inc": inc,
                "$set": {"updated_at": datetime.now(timezone.utc)},
            },
            upsert=True,
        )
        # Clamp at zero so skips can't drive affinities negative.
        clamp = []
        if lang:
            clamp.append((f"languages.{lang}", f"$languages.{lang}"))
        if genre:
            clamp.append((f"genres.{genre}", f"$genres.{genre}"))
        await profile_collection.update_one(
            {"_id": PROFILE_ID},
            [
                {
                    "$set": {
                        path: {"$max": [0.0, ref]}
                        for path, ref in clamp
                    }
                }
            ],
        )
        return True
    except Exception:
        return False


async def decay_profiles(rate: float = 0.9) -> int:
    """Multiply every affinity by ``rate`` (weekly background job)."""
    rate = max(0.0, min(1.0, float(rate)))
    pipeline = [
        {
            "$set": {
                "languages": {
                    "$arrayToObject": {
                        "$map": {
                            "input": {"$objectToArray": "$languages"},
                            "as": "kv",
                            "in": {
                                "k": "$$kv.k",
                                "v": {"$round": [{"$multiply": ["$$kv.v", rate]}, 2]},
                            },
                        }
                    }
                },
                "genres": {
                    "$arrayToObject": {
                        "$map": {
                            "input": {"$objectToArray": "$genres"},
                            "as": "kv",
                            "in": {
                                "k": "$$kv.k",
                                "v": {"$round": [{"$multiply": ["$$kv.v", rate]}, 2]},
                            },
                        }
                    }
                },
                "last_decay": datetime.now(timezone.utc),
            }
        }
    ]
    try:
        res = await profile_collection.update_many({}, pipeline)
        return res.modified_count
    except Exception:
        return 0
