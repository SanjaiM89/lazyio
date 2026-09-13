"""Track metadata lookup via the iTunes Search API (free, no key required).

Used by the channel indexer: Telegram documents rarely carry embedded
pictures or album tags, so we resolve artwork + album (+ canonical artist)
by title + artist instead of downloading every file for fingerprinting.
"""

import asyncio
import urllib.parse

import httpx

_ITUNES_URL = "https://itunes.apple.com/search"
_cache: dict = {}

# Shared throttle state: when Apple answers 429, ALL lookups pause instead
# of hammering through retries (which only extends the throttle window).
_throttled_until = 0.0
_THROTTLE_PAUSE_SECONDS = 30.0


class TransientStoreError(Exception):
    """Transport failure (timeout, rate-limit, HTTP error).

    Callers must NOT treat this as "no match": nothing is cached and no
    negative flags are written, so the next scan retries.
    """


def _cache_key(title: str, artist: str) -> str:
    return f"{(artist or '').strip().lower()}|{(title or '').strip().lower()}"


async def fetch_track_meta(title: str, artist: str = "") -> dict | None:
    """Return {artwork, album, artist, year, genre} for a track, or None.

    album comes from iTunes' collectionName — for movie soundtracks this is
    the movie/album name, which is what groups those songs into one album.
    The top result is validated against our title (and artist, when known)
    so bad matches can't pollute grouping or artwork. Falls back to a
    title-only query when the artist-qualified query has no valid match
    (stored artists are often wrong, e.g. movie names or filenames).
    """
    from app.db.crud.songs import (
        normalize_title_for_grouping,
        normalize_artist_for_grouping,
    )

    key = _cache_key(title, artist)
    if key in _cache:
        return _cache[key]

    artist_known = bool((artist or "").strip()) and (artist or "").strip().lower() not in (
        "unknown artist",
        "unknown",
    )
    queries = []
    if artist_known:
        queries.append(f"{artist} {title}".strip())
    # Title-only queries match better when our artist is unknown — or wrong.
    if (title or "").strip():
        queries.append(title.strip())
    if not queries:
        return None

    meta = None
    try:
        for query in queries:
            meta = await _query_store(
                query, title, artist if artist_known else "", artist_known
            )
            if meta:
                break
    except TransientStoreError:
        # Transport failure: propagate WITHOUT caching so the next scan
        # retries instead of blacklisting the song.
        raise
    _cache[key] = meta
    return meta


async def _raw_search(query: str) -> list:
    """Raw top-3 store results. Raises TransientStoreError on transport failure."""
    global _throttled_until
    import time as _time

    # Honor a previous 429: pause everything instead of extending the ban.
    now = _time.monotonic()
    if now < _throttled_until:
        wait = _throttled_until - now
        print(f"[ARTWORK] throttled, pausing lookups for {wait:.0f}s")
        await asyncio.sleep(wait)

    params = {
        "term": query,
        "media": "music",
        "entity": "song",
        "limit": 3,
    }
    url = f"{_ITUNES_URL}?{urllib.parse.urlencode(params)}"
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url)
            if resp.status_code == 429:
                _throttled_until = _time.monotonic() + _THROTTLE_PAUSE_SECONDS
                raise TransientStoreError(
                    f"HTTP 429 for {query!r} (pausing lookups "
                    f"{_THROTTLE_PAUSE_SECONDS:.0f}s)"
                )
            if resp.status_code == 403:
                # Apple is rate-blocking this client IP: back off like a
                # 429 instead of hammering every song through the block.
                _throttled_until = _time.monotonic() + _THROTTLE_PAUSE_SECONDS
                raise TransientStoreError(
                    f"HTTP 403 for {query!r} (client blocked, pausing lookups "
                    f"{_THROTTLE_PAUSE_SECONDS:.0f}s)"
                )
            if resp.status_code != 200:
                raise TransientStoreError(f"HTTP {resp.status_code} for {query!r}")
            return resp.json().get("results", [])
    except TransientStoreError:
        raise
    except Exception as e:
        raise TransientStoreError(f"{type(e).__name__}: {e} (query={query!r}")


async def _query_store(
    query: str, title: str, artist: str, artist_known: bool
) -> dict | None:
    """First validated match; None = definitive "no valid match" (safe to cache)."""
    results = await _raw_search(query)
    # Scan top-3 and take the first VALIDATED match, not just top-1.
    for top in results:
        if not _titles_match(title, top.get("trackName", "")):
            continue
        if artist_known and not _artists_match(
            artist, top.get("artistName", "")
        ):
            continue
        art = top.get("artworkUrl100", "")
        year = None
        release = top.get("releaseDate", "")
        if len(release) >= 4 and release[:4].isdigit():
            year = int(release[:4])
        meta = {
            # Upscale Apple's 100x100 thumb to 600x600.
            "artwork": art.replace("100x100bb", "600x600bb") if art else None,
            "album": (top.get("collectionName") or "").strip() or None,
            "artist": (top.get("artistName") or "").strip() or None,
            "year": year,
            "genre": (top.get("primaryGenreName") or "").strip() or None,
        }
        # Be gentle with the free API during bulk scans.
        await asyncio.sleep(0.3)
        return meta
    return None


def _token_overlap(a: str, b: str) -> float:
    ta, tb = set(a.split()), set(b.split())
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / min(len(ta), len(tb))


def _titles_match(ours: str, theirs: str) -> bool:
    from app.db.crud.songs import normalize_title_for_grouping

    a = normalize_title_for_grouping(ours)
    b = normalize_title_for_grouping(theirs)
    if not a or not b:
        return False
    if a == b or a in b or b in a:
        return True
    return _token_overlap(a, b) >= 0.6


def _artists_match(ours: str, theirs: str) -> bool:
    from app.db.crud.songs import normalize_artist_for_grouping

    a = normalize_artist_for_grouping(ours)
    b = normalize_artist_for_grouping(theirs)
    if not a or not b:
        return False
    if a == b or a in b or b in a:
        return True
    return _token_overlap(a, b) >= 0.6


async def fetch_cover_art(title: str, artist: str = "") -> str | None:
    """Return a hi-res artwork URL for a track, or None."""
    meta = await fetch_track_meta(title, artist)
    return meta["artwork"] if meta else None


async def fetch_artist_art(artist: str) -> str | None:
    """Fallback artist image: artwork of the store's top song result.

    iTunes artist entities carry no artwork, so the most relevant track's
    art stands in for the artist. Returns None on transport failure too
    (callers treat both as "try again later").
    """
    name = (artist or "").strip()
    if not name or name.lower() in ("unknown artist", "unknown"):
        return None
    key = f"artist:{name.lower()}"
    if key in _cache:
        return _cache[key]
    global _throttled_until
    import time as _time

    now = _time.monotonic()
    if now < _throttled_until:
        await asyncio.sleep(_throttled_until - now)
    params = {"term": name, "media": "music", "entity": "song", "limit": 5}
    url = f"{_ITUNES_URL}?{urllib.parse.urlencode(params)}"
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url)
            if resp.status_code != 200:
                return None
            for top in resp.json().get("results", []):
                art = top.get("artworkUrl100", "")
                if art:
                    hi_res = art.replace("100x100bb", "600x600bb")
                    _cache[key] = hi_res
                    await asyncio.sleep(0.3)
                    return hi_res
            _cache[key] = None
            return None
    except Exception as e:
        print(f"[ARTWORK] artist lookup failed for {name!r}: {type(e).__name__}: {e}")
        return None


async def debug_match(title: str, artist: str = "") -> dict:
    """Diagnostics for GET /api/telegram/test-match (nothing is cached).

    Shows every query tried plus each raw candidate with its accept/reject
    reason, so mistuned matching can be diagnosed with real data.
    """
    from app.db.crud.songs import (
        normalize_title_for_grouping,
        normalize_artist_for_grouping,
    )

    artist_known = bool((artist or "").strip()) and (artist or "").strip().lower() not in (
        "unknown artist",
        "unknown",
    )
    queries = []
    if artist_known:
        queries.append(f"{artist} {title}".strip())
    if (title or "").strip():
        queries.append(title.strip())

    out = {"title": title, "artist": artist, "queries": []}
    for query in queries:
        entry = {"query": query, "candidates": [], "transport_error": None}
        try:
            results = await _raw_search(query)
        except TransientStoreError as e:
            entry["transport_error"] = str(e)
            out["queries"].append(entry)
            break
        for top in results:
            t_name, a_name = top.get("trackName", ""), top.get("artistName", "")
            norm_ours = normalize_title_for_grouping(title)
            norm_theirs = normalize_title_for_grouping(t_name)
            title_ok = _titles_match(title, t_name)
            if artist_known:
                artist_ok = _artists_match(artist, a_name)
            else:
                artist_ok = True
            if title_ok and artist_ok:
                reason = "accepted"
            elif not title_ok:
                reason = (
                    f"title mismatch: ours={norm_ours!r} theirs={norm_theirs!r}"
                )
            else:
                reason = (
                    f"artist mismatch: ours={normalize_artist_for_grouping(artist)!r} "
                    f"theirs={normalize_artist_for_grouping(a_name)!r}"
                )
            entry["candidates"].append(
                {
                    "trackName": t_name,
                    "artistName": a_name,
                    "collectionName": top.get("collectionName", ""),
                    "accepted": title_ok and artist_ok,
                    "reason": reason,
                }
            )
        out["queries"].append(entry)
        if any(c["accepted"] for c in entry["candidates"]):
            break
    return out
