"""Lyrics lookup via LRCLIB (free, no API key required).

Library tracks come from Telegram channels, so stored titles/artists are often
noisy ("Song (Official Video)", "Artist - Topic"). LRCLIB's exact endpoint
rejects those, so lookups go through title/artist cleaning first and fall back
to a scored search before giving up. Everything fetched here is persisted by
``get_lyrics_for_song`` (see app.db.crud.lyrics) so the library is only ever
queried once per track.
"""

import asyncio
import re
import time
from difflib import SequenceMatcher

import httpx

from app.db.crud.lyrics import get_cached_lyrics, match_key_for, save_lyrics
from app.db.crud.songs import (
    normalize_artist_for_grouping,
    normalize_title_for_grouping,
)

_LRCLIB_URL = "https://lrclib.net/api"
_HEADERS = {"User-Agent": "Lazyio/1.0 (https://github.com/SanjaiM89/lazyio)"}
_HTTP_TIMEOUT = 8.0
_REQUEST_SPACING = 0.2  # be polite: LRCLIB is a community service

# How long a lookup result is trusted in memory before it is redone.
_HIT_TTL_SECONDS = 6 * 3600
_MISS_TTL_SECONDS = 3600
_MEMORY_CACHE_LIMIT = 1000

_SCORE_ACCEPT = 0.6  # minimum combined similarity for a search hit
_TITLE_ACCEPT = 0.6  # title alone must be at least this similar
_DURATION_TOLERANCE = 10.0  # seconds; duration is a soft signal, not a gate
_RETRY_STATUSES = {500, 502, 503, 504}
_RETRY_BACKOFF = 1.0  # seconds before retrying a transient failure

_GENERIC_ARTISTS = {"", "unknown artist", "unknown"}

_LRC_STAMP_RE = re.compile(r"\[(\d{1,3}):(\d{1,2}(?:\.\d{1,3})?)\]")
_BRACKETS_RE = re.compile(r"[\(\[\{][^\)\]\}]*[\)\]\}]")
_NOISE_RE = re.compile(
    r"\b("
    r"official(ly)?\s+(music\s+)?(video|audio|lyric\s+video|visuali[sz]er)"
    r"|official"
    r"|music\s+video"
    r"|lyric\s+video|lyrics\s+video|lyrics?|lyric"
    r"|visuali[sz]er"
    r"|audio"
    r"|remaster(ed)?"
    r"|hq|hd|4k|mv"
    r")\b",
    re.IGNORECASE,
)
_EXT_RE = re.compile(
    r"\.(mp3|m4a|flac|wav|ogg|opus|aac|mp4|mkv|webm|avi|mov)$", re.IGNORECASE
)

_MISSING = object()
_cache: dict = {}
_locks: dict = {}

_throttled_until = 0.0
_THROTTLE_PAUSE_SECONDS = 30.0


class TransientLyricsError(Exception):
    """Transport failure (timeout / 5xx / rate limit) — never cached as a miss."""


# --------------------------------------------------------------------------- #
# Text cleaning / matching
# --------------------------------------------------------------------------- #


def _clean_query_title(title: str | None) -> str:
    """Query-friendly title: drop extensions, brackets and quality qualifiers."""
    value = (title or "").strip()
    value = _EXT_RE.sub("", value)
    # Separators first so qualifiers glued by "_" ("song_hq") get word
    # boundaries and are removed by the noise pass below.
    value = re.sub(r"[_.]+", " ", value)
    value = _BRACKETS_RE.sub(" ", value)
    value = _NOISE_RE.sub(" ", value)
    return re.sub(r"\s+", " ", value).strip(" -_")


def _clean_query_artist(artist: str | None) -> str:
    """Query-friendly artist: strip YouTube auto-channel / VEVO markers."""
    value = (artist or "").strip()
    value = re.sub(r"\s*-\s*topic\s*$", "", value, flags=re.IGNORECASE)
    # No leading \b: YouTube VEVO channels glue it on ("ArtistVEVO").
    value = re.sub(r"vevo\b", " ", value, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", value).strip(" -_")


def _similarity(left: str | None, right: str | None) -> float:
    left, right = (left or "").strip().lower(), (right or "").strip().lower()
    if not left or not right:
        return 0.0
    if left == right:
        return 1.0
    return SequenceMatcher(None, left, right).ratio()


def _artist_known(artist: str | None) -> bool:
    return (artist or "").strip().lower() not in _GENERIC_ARTISTS


def _candidate_score(candidate: dict, title: str, artist: str, duration) -> tuple:
    """Return (title_similarity, combined_score) for one LRCLIB search hit."""
    title_score = _similarity(
        normalize_title_for_grouping(title),
        normalize_title_for_grouping(candidate.get("trackName") or candidate.get("name")),
    )
    duration_score = 0.0
    try:
        if duration and candidate.get("duration"):
            delta = abs(float(candidate["duration"]) - float(duration))
            duration_score = max(0.0, 1.0 - delta / _DURATION_TOLERANCE)
    except (TypeError, ValueError):
        duration_score = 0.0

    if _artist_known(artist):
        artist_score = _similarity(
            normalize_artist_for_grouping(artist),
            normalize_artist_for_grouping(candidate.get("artistName")),
        )
        score = 0.55 * title_score + 0.25 * artist_score + 0.20 * duration_score
    else:
        score = 0.80 * title_score + 0.20 * duration_score
    if candidate.get("syncedLyrics"):
        score += 0.02  # prefer hits we can actually sync
    return title_score, score


def _pick_best(candidates: list, title: str, artist: str, duration) -> dict | None:
    """Best search hit by title/artist/duration similarity, or None."""
    best, best_score = None, 0.0
    for candidate in candidates:
        title_score, score = _candidate_score(candidate, title, artist, duration)
        norm_title = normalize_title_for_grouping(title)
        norm_candidate = normalize_title_for_grouping(
            candidate.get("trackName") or candidate.get("name")
        )
        if norm_title and norm_candidate and norm_title == norm_candidate:
            title_score = 1.0  # exact after cleaning: trust it
        if title_score < _TITLE_ACCEPT:
            continue
        if score > best_score:
            best, best_score = candidate, score
    return best if best_score >= _SCORE_ACCEPT else None


def parse_lrc(synced: str | None) -> list:
    """LRC text -> ``[{time, text}]`` sorted by time.

    Multiple timestamps per line are expanded and instrumental gaps (empty
    text) are dropped, so the UI only ever highlights real lines.
    """
    stamped: list = []
    for raw in (synced or "").splitlines():
        stamps = _LRC_STAMP_RE.findall(raw)
        if not stamps:
            continue
        text = _LRC_STAMP_RE.sub("", raw).strip()
        if not text:
            continue
        for minutes, seconds in stamps:
            stamped.append((int(minutes) * 60 + float(seconds), text))
    stamped.sort(key=lambda item: item[0])
    lines: list = []
    for at, text in stamped:
        if lines and at - lines[-1]["time"] < 0.05:
            continue  # duplicate timestamp
        lines.append({"time": round(at, 2), "text": text})
    return lines


def _build_payload(data: dict) -> dict:
    """Normalize a raw LRCLIB record into the shape the clients consume."""
    lines = parse_lrc(data.get("syncedLyrics"))
    return {
        "instrumental": bool(data.get("instrumental")),
        "synced": bool(lines),
        "source": "lrclib",
        "lines": lines,
        "plain": (data.get("plainLyrics") or "").strip(),
        "matched": {
            "title": data.get("trackName") or data.get("name"),
            "artist": data.get("artistName"),
            "album": data.get("albumName"),
            "duration": data.get("duration"),
        },
    }


# --------------------------------------------------------------------------- #
# LRCLIB client
# --------------------------------------------------------------------------- #


async def _request(client: httpx.AsyncClient, path: str, params: dict) -> httpx.Response:
    """One LRCLIB call, retried once for transient failures.

    Raises TransientLyricsError when the library is unreachable or throttling,
    so callers can surface "try again" instead of caching a false negative.
    """
    global _throttled_until

    now = time.monotonic()
    if now < _throttled_until:
        wait = _throttled_until - now
        print(f"[LYRICS] throttled, pausing lookups for {wait:.0f}s")
        await asyncio.sleep(wait)

    last_error: object = None
    for attempt in (1, 2):
        try:
            response = await client.get(
                f"{_LRCLIB_URL}{path}", params=params, headers=_HEADERS
            )
        except httpx.HTTPError as exc:
            response, last_error = None, exc
        if response is not None:
            if response.status_code == 429:
                # Shared pause: retrying immediately only extends the ban.
                _throttled_until = time.monotonic() + _THROTTLE_PAUSE_SECONDS
                raise TransientLyricsError("rate limited by LRCLIB")
            if response.status_code not in _RETRY_STATUSES:
                await asyncio.sleep(_REQUEST_SPACING)
                return response
            last_error = f"HTTP {response.status_code}"
        if attempt == 1:
            await asyncio.sleep(_RETRY_BACKOFF)
    raise TransientLyricsError(f"LRCLIB request failed: {last_error}")


async def _lookup_exact(
    client: httpx.AsyncClient,
    track_name: str,
    artist_name: str,
    album_name: str | None,
    duration,
) -> dict | None:
    """``/api/get`` — fast path. None when the track is unknown to LRCLIB."""
    params: dict = {"track_name": track_name, "artist_name": artist_name}
    if album_name:
        params["album_name"] = album_name
    if duration:
        try:
            params["duration"] = str(int(round(float(duration))))
        except (TypeError, ValueError):
            pass
    response = await _request(client, "/get", params)
    if response.status_code == 404:
        return None
    if response.status_code != 200:
        raise TransientLyricsError(f"LRCLIB /get returned {response.status_code}")
    return response.json()


async def _lookup_search(
    client: httpx.AsyncClient,
    track_name: str | None = None,
    artist_name: str | None = None,
    free_text: str | None = None,
) -> list:
    """``/api/search`` — raw candidates ([] when nothing matches)."""
    params: dict = {}
    if free_text:
        params["q"] = free_text
    else:
        if track_name:
            params["track_name"] = track_name
        if artist_name:
            params["artist_name"] = artist_name
    response = await _request(client, "/search", params)
    if response.status_code != 200:
        raise TransientLyricsError(f"LRCLIB /search returned {response.status_code}")
    data = response.json()
    return data if isinstance(data, list) else []


def _unique_candidates(pairs: list) -> list:
    """Drop empty/duplicate (title, artist) query attempts."""
    seen, out = set(), []
    for title, artist in pairs:
        title, artist = (title or "").strip(), (artist or "").strip()
        key = (title.lower(), artist.lower())
        if not title or key in seen:
            continue
        seen.add(key)
        out.append((title, artist))
    return out



async def fetch_lyrics(
    title: str, artist: str = "", album: str = "", duration=None
) -> dict | None:
    """Look a track up on LRCLIB. Returns a normalized payload, or None.

    Raises TransientLyricsError on transport failure so callers avoid caching
    a false negative.
    """
    title = (title or "").strip()
    if not title:
        return None
    clean_title = _clean_query_title(title) or title
    clean_artist = _clean_query_artist(artist)
    clean_album = (album or "").strip()

    async with httpx.AsyncClient(timeout=_HTTP_TIMEOUT) as client:
        # 1. Exact match: cleaned values first, then the raw title; album is
        #    tried both ways because stored album tags are often wrong.
        for attempt_title, attempt_artist in _unique_candidates(
            [(clean_title, clean_artist), (title, clean_artist)]
        ):
            for attempt_album in ([clean_album, None] if clean_album else [None]):
                hit = await _lookup_exact(
                    client, attempt_title, attempt_artist, attempt_album, duration
                )
                if hit:
                    return _build_payload(hit)

        # 2. Scored search on title (+ artist), then title alone.
        for attempt_title, attempt_artist in _unique_candidates(
            [(clean_title, clean_artist), (clean_title, "")]
        ):
            candidates = await _lookup_search(client, attempt_title, attempt_artist)
            best = _pick_best(candidates, title, clean_artist, duration)
            if best:
                return _build_payload(best)

        # 3. Free-text last resort.
        query = " ".join(part for part in (clean_artist, clean_title) if part) or title
        candidates = await _lookup_search(client, free_text=query)
        best = _pick_best(candidates, title, clean_artist, duration)
        if best:
            return _build_payload(best)

    return None


# --------------------------------------------------------------------------- #
# Cache-aware entry point
# --------------------------------------------------------------------------- #


def _memory_get(key: str):
    entry = _cache.get(key)
    if not entry:
        return _MISSING
    stored_at, payload = entry
    ttl = _HIT_TTL_SECONDS if payload else _MISS_TTL_SECONDS
    if time.monotonic() - stored_at > ttl:
        _cache.pop(key, None)
        return _MISSING
    return payload


def _memory_put(key: str, payload: dict | None) -> None:
    if len(_cache) >= _MEMORY_CACHE_LIMIT:
        _cache.clear()
    _cache[key] = (time.monotonic(), payload)


async def _enrich_song_from_lyrics(song: dict, payload: dict | None) -> None:
    """Label unlabeled songs from fresh LRCLIB payloads.

    - Lyrics script (sustained run) -> ``language`` (source ``auto:lyrics``).
    - LRCLIB ``instrumental`` flag -> ``lyrics_instrumental`` hint, merged
      into ``is_instrumental`` for songs without audio analysis yet.
    """
    from app.services.language import detect_from_lyrics
    from app.db.crud.songs import set_song_language, set_lyrics_instrumental

    if not song or not payload:
        return
    song_id = str(song.get("_id")) if song.get("_id") else None
    if not song_id:
        return
    if not song.get("language"):
        lang, _ = detect_from_lyrics(payload.get("plain") or "")
        if lang:
            await set_song_language(song_id, lang, source="auto:lyrics")
    if payload.get("instrumental") and not (song.get("audio") or {}):
        await set_lyrics_instrumental(song_id, True)


async def get_lyrics_for_song(song: dict, refresh: bool = False) -> dict:
    """Cache-first lyrics for one stored song row.

    Order: in-memory -> Mongo (``lyrics`` collection) -> LRCLIB -> Mongo.
    Once a track has been fetched it is served from storage, so the lyrics
    library is never queried again for the same song.

    Returns ``{"cached": bool, "lyrics": payload | None}``; raises
    TransientLyricsError when the library is unreachable.
    """
    song_id = str(song.get("_id")) if song.get("_id") else None
    title = song.get("title") or ""
    artist = song.get("artist") or ""
    album = song.get("album") or ""
    duration = song.get("duration")
    key = match_key_for(title, artist, duration)

    if not refresh:
        memory = _memory_get(key)
        if memory is not _MISSING:
            return {"cached": True, "lyrics": memory}
        stored = await get_cached_lyrics(song_id=song_id, match_key=key)
        if stored is not None:
            payload = None
            if stored.get("found"):
                payload = {
                    "instrumental": stored.get("instrumental", False),
                    "synced": stored.get("synced", False),
                    "source": stored.get("source") or "lrclib",
                    "lines": stored.get("lines") or [],
                    "plain": stored.get("plain") or "",
                    "matched": stored.get("matched") or {},
                }
            _memory_put(key, payload)
            return {"cached": True, "lyrics": payload}

    # One lookup per track even under concurrent requests.
    lock = _locks.setdefault(key, asyncio.Lock())
    async with lock:
        if not refresh:
            memory = _memory_get(key)
            if memory is not _MISSING:
                return {"cached": True, "lyrics": memory}

        payload = await fetch_lyrics(title, artist, album, duration)
        _memory_put(key, payload)
        if song_id:
            # Persist before returning: the next request must not need LRCLIB.
            await save_lyrics(song_id, key, payload)
            # Fresh lyrics are a strong language signal: label unlabeled
            # songs from the lyrics script, and record LRCLIB's instrumental
            # flag when no audio analysis exists yet.
            try:
                await _enrich_song_from_lyrics(song, payload)
            except Exception as e:
                print(f"[LYRICS] language hook skipped for {song_id}: {e}")
        if payload is None:
            print(f"[LYRICS] no lyrics found for {title!r} / {artist!r}")
        return {"cached": False, "lyrics": payload}

