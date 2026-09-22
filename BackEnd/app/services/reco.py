"""Hybrid recommendations: content similarity + behavior (Phase 3).

Spotify playbook, adapted to a single-user self-hosted library:

- **Content layer**: FAISS cosine/Euclidean neighbors over the 19-dim
  librosa vectors (bpm, energy, instrumentalness, lo-fi, valence, MFCCs).
- **Behavioral layer**: next-track co-occurrence. Play history is a flat
  ``{song_id, played_at}`` log, so sessions are derived by time-gap
  segmentation (``SESSION_GAP_SECONDS``); every adjacent pair inside a
  session votes once for the transition ``current -> next``.
- **Hybrid merge**: each layer is min-max normalized to weight 0.5 and
  summed (max 1.0). Cold-start tracks (no transitions) fall back to
  content-only; viral transitions can surface behavior-only tracks.
- Optional same-language hard filter + user-affinity multiplier
  (Phase 4 profile) keep results coherent and personal.

Pure helpers (``segment_sessions``, ``count_transitions``,
``minmax_normalize``, ``merge_hybrid``) are stdlib/numpy-free and covered
by BackEnd/tests/test_hybrid.py.
"""

import logging
from datetime import datetime, timezone

logger = logging.getLogger("HybridReco")

SESSION_GAP_SECONDS = 30 * 60


# ---------------------------------------------------------------------------
# Pure helpers (no I/O).
# ---------------------------------------------------------------------------

def _to_epoch(ts) -> float:
    if ts is None:
        return 0.0
    if isinstance(ts, (int, float)):
        return float(ts)
    if isinstance(ts, datetime):
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return ts.timestamp()
    return 0.0


def segment_sessions(events, gap_seconds: int = SESSION_GAP_SECONDS) -> list:
    """Group ``(song_id, played_at)`` events into sessions.

    Events sorted by time; a gap longer than ``gap_seconds`` starts a new
    session. Returns a list of song-id lists.
    """
    ordered = sorted(events, key=lambda e: _to_epoch(e[1]))
    sessions, current, last_ts = [], [], None
    for sid, ts in ordered:
        if not sid:
            continue
        epoch = _to_epoch(ts)
        if last_ts is not None and epoch - last_ts > gap_seconds:
            if current:
                sessions.append(current)
            current = []
        current.append(sid)
        last_ts = epoch
    if current:
        sessions.append(current)
    return sessions


def count_transitions(sessions) -> dict:
    """``{song_id: {next_id: count}}`` over adjacent in-session pairs."""
    transitions = {}
    for sess in sessions:
        for a, b in zip(sess, sess[1:]):
            if not a or not b or a == b:
                continue
            nxt = transitions.setdefault(a, {})
            nxt[b] = nxt.get(b, 0) + 1
    return transitions


def minmax_normalize(items: list, score_key: str, weight: float = 0.5) -> list:
    """Scale ``score_key`` values into [0, weight] in place (copy-safe)."""
    out = [dict(r) for r in items]
    if not out:
        return out
    scores = [float(r.get(score_key) or 0.0) for r in out]
    lo, hi = min(scores), max(scores)
    if hi <= lo:
        for r in out:
            r["normalized_score"] = float(weight)
        return out
    for r, s in zip(out, scores):
        r["normalized_score"] = ((s - lo) / (hi - lo)) * float(weight)
    return out


def merge_hybrid(vector_items: list, behav_items: list, limit: int = 10,
                 id_key: str = "id") -> list:
    """Merge normalized layers into ranked ``[{..., final_score}]``."""
    merged = {}
    for track in vector_items:
        tid = str(track.get(id_key))
        merged[tid] = dict(track)
        merged[tid]["final_score"] = float(track.get("normalized_score", 0.0))
    for track in behav_items:
        tid = str(track.get(id_key))
        if tid in merged:
            merged[tid]["final_score"] += float(track.get("normalized_score", 0.0))
        else:
            merged[tid] = dict(track)
            merged[tid]["final_score"] = float(track.get("normalized_score", 0.0))
    ranked = sorted(merged.values(), key=lambda t: -t["final_score"])
    return ranked[: max(1, limit)]


# ---------------------------------------------------------------------------
# DB-backed layers.
# ---------------------------------------------------------------------------

async def get_transition_counts(song_id: str) -> dict:
    """``{next_song_id: plays-right-after}`` for one seed song."""
    from app.db.connection import history_collection

    events = []
    async for doc in history_collection.find(
        {}, projection={"song_id": 1, "played_at": 1}
    ).sort("played_at", 1):
        events.append((doc.get("song_id"), doc.get("played_at")))
    transitions = count_transitions(segment_sessions(events))
    return transitions.get(song_id, {})


async def get_hybrid_similar(song_id: str, limit: int = 10,
                             same_language: bool = True,
                             affinity: dict = None) -> list:
    """Ranked song dicts blending FAISS similarity + co-occurrence.

    ``affinity`` maps ``{"languages": {lang: w}, "genres": {genre: w}}``
    (Phase 4 profile) and gently boosts matching tracks.
    """
    from app.db.crud.songs import get_song_by_id
    from app.ai.recommender import audio_recommender
    from app.services.language import normalize_language

    seed = await get_song_by_id(song_id)
    if not seed:
        return []
    seed_lang = normalize_language(seed.get("language"))
    aff_langs = (affinity or {}).get("languages", {}) or {}
    aff_genres = (affinity or {}).get("genres", {}) or {}

    # Layer 1 — content: FAISS neighbors, rank-decayed scores.
    vector_items = []
    try:
        neighbor_ids = audio_recommender.find_similar(song_id, limit * 2)
        for rank, nid in enumerate(neighbor_ids):
            vector_items.append({"id": nid, "score": 1.0 / (1.0 + rank)})
    except Exception as e:
        logger.warning(f"vector layer failed for {song_id}: {e}")
    vector_items = minmax_normalize(vector_items, "score", 0.5)

    # Layer 2 — behavior: next-track frequencies.
    behav_items = []
    try:
        counts = await get_transition_counts(song_id)
        for nid, freq in sorted(counts.items(), key=lambda kv: -kv[1])[: limit * 2]:
            behav_items.append({"id": nid, "frequency": freq})
    except Exception as e:
        logger.warning(f"behavioral layer failed for {song_id}: {e}")
    behav_items = minmax_normalize(behav_items, "frequency", 0.5)

    merged = merge_hybrid(vector_items, behav_items, limit=limit * 2)

    # Resolve + filter + affinity boost.
    results = []
    for track in merged:
        if str(track.get("id")) == str(song_id):
            continue
        song = await get_song_by_id(track["id"])
        if not song:
            continue
        if same_language and seed_lang:
            if normalize_language(song.get("language")) != seed_lang:
                continue
        final = float(track.get("final_score", 0.0))
        if aff_langs or aff_genres:
            boost = 1.0
            lw = aff_langs.get(normalize_language(song.get("language")) or "")
            if lw:
                boost += 0.01 * float(lw)
            gw = aff_genres.get((song.get("genre") or ""))
            if gw:
                boost += 0.01 * float(gw)
            final *= boost
        song = dict(song)
        song["reco_score"] = round(final, 4)
        results.append(song)
        if len(results) >= limit:
            break
    results.sort(key=lambda s: -s.get("reco_score", 0.0))
    return results
