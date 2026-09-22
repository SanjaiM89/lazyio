"""Spotify-style in-memory search engine for Lazyio.

How it maps to the Spotify playbook:
- Inverted index  : token -> {doc_id: field_weight} (like Lucene postings).
                    Queries hit the index, never a full collection scan.
- Prefix / trie    : sorted vocabulary + bisect gives prefix autocomplete
                    (tries) in O(log V + expansions).
- Typo tolerance   : SymSpell-style delete-index over vocabulary tokens +
                    true Damerau-Levenshtein verification (edit distance <= 2).
- Caching          : LRU result cache with TTL (like Redis/CDN layer) keyed
                    by (query, limit, kind).
- Personal ranking : text score boosted by play_count (popularity),
                    liked songs (affinity) and recent plays (temporal context).
- Light payloads   : `suggest()` returns minimal id/title/artist documents
                    for as-you-type autocomplete.

Stdlib only. The index is rebuilt in the background when the library
changes (count check, throttled) or ages out.
"""

import bisect
import math
import re
import time
from collections import OrderedDict

from app.services.language import parse_language_intent, normalize_language

# Field weights: a title match outranks an artist match outranks an album hit.
TITLE_W = 3.0
ARTIST_W = 2.0
ALBUM_W = 1.0

# Match-type multipliers.
EXACT_W = 1.0
PREFIX_W = 0.85
TYPO_W = 0.7

# Personalization weights.
PLAY_W = 0.15
LIKED_W = 0.5
RECENT_W = 0.3
RECENT_HALF_LIFE_DAYS = 7.0

CACHE_TTL_S = 60
CACHE_MAX = 256
INDEX_MAX_AGE_S = 300
DIRTY_CHECK_MIN_S = 15
MAX_PREFIX_EXPANSIONS = 25


def tokenize(text):
    """Lowercase alphanumeric tokens (the analyzer)."""
    if not text:
        return []
    text = str(text).lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return [t for t in text.split() if t]


def _deletes(token, max_dist):
    """All strings formed by deleting 1..max_dist chars (SymSpell index)."""
    out = set()
    queue = {token}
    for _ in range(max_dist):
        nxt = set()
        for s in queue:
            if len(s) <= 1:
                continue
            for i in range(len(s)):
                d = s[:i] + s[i + 1 :]
                if d not in out:
                    out.add(d)
                    nxt.add(d)
        queue = nxt
    return out


def _max_dist(token):
    if len(token) >= 6:
        return 2
    if len(token) >= 3:
        return 1
    return 0


def levenshtein(a, b, limit=2):
    """True edit distance with early exit past `limit` (banded DP)."""
    if a == b:
        return 0
    la, lb = len(a), len(b)
    if abs(la - lb) > limit:
        return limit + 1
    if la > lb:
        a, b = b, a
        la, lb = lb, la
    prev = list(range(la + 1))
    for i in range(1, lb + 1):
        cur = [i] + [0] * la
        lo = max(1, i - limit - 1)
        hi = min(la, i + limit + 1)
        row_min = limit + 1
        bc = b[i - 1]
        for j in range(lo, hi + 1):
            cost = 0 if a[j - 1] == bc else 1
            v = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            cur[j] = v
            if v < row_min:
                row_min = v
        if row_min > limit:
            return limit + 1
        prev = cur
    return prev[la]


class SearchIndex:
    """Pure in-memory index: build from plain dicts, no I/O (testable)."""

    def __init__(self):
        # token -> {doc_id: weight}
        self.postings = {}
        # delete-string -> set(tokens)
        self.deletes = {}
        self.vocab = []  # sorted token list for prefix scan
        self.songs = {}  # id -> song_helper dict
        self.song_tokens = {}  # id -> {token: weight}
        self.albums = {}  # id -> album dict
        self.album_tokens = {}
        self.artists = {}  # key -> artist dict
        self.artist_tokens = {}
        self.liked = set()
        self.recent = {}  # song_id -> played_at epoch
        self._cache = OrderedDict()

    # ---------------- build ----------------

    def build(self, song_docs, album_docs, liked_ids=(), recent_map=None):
        self.postings = {}
        self.deletes = {}
        self.songs = {}
        self.song_tokens = {}
        self.albums = {}
        self.album_tokens = {}
        self.artists = {}
        self.artist_tokens = {}
        self.liked = set(liked_ids or ())
        self.recent = dict(recent_map or {})
        self._cache.clear()

        for s in song_docs:
            sid = s.get("id")
            if not sid:
                continue
            self.songs[sid] = s
            toks = {}
            for t in tokenize(s.get("title")):
                toks[t] = max(toks.get(t, 0), TITLE_W)
            for t in tokenize(s.get("artist")):
                toks[t] = max(toks.get(t, 0), ARTIST_W)
            for t in tokenize(s.get("album")):
                toks[t] = max(toks.get(t, 0), ALBUM_W)
            self.song_tokens[sid] = toks
            for t, w in toks.items():
                self.postings.setdefault(t, {})[sid] = w

        for a in album_docs or ():
            aid = a.get("id")
            if not aid:
                continue
            self.albums[aid] = a
            toks = {}
            for t in tokenize(a.get("name")):
                toks[t] = max(toks.get(t, 0), TITLE_W)
            for t in tokenize(a.get("artist")):
                toks[t] = max(toks.get(t, 0), ARTIST_W)
            self.album_tokens[aid] = toks
            for t, w in toks.items():
                self.postings.setdefault(t, {})[f"al:{aid}"] = w

        # Artists roll up from songs (no extra queries, no cover API calls).
        buckets = {}
        for sid, s in self.songs.items():
            raw = (s.get("artist") or "").strip()
            if not raw or raw in ("Unknown Artist", "Unknown"):
                continue
            key = re.sub(r"[^a-z0-9]+", " ", raw.lower()).strip()
            b = buckets.setdefault(key, {"names": {}, "songs": []})
            b["names"][raw] = b["names"].get(raw, 0) + 1
            b["songs"].append(s)
        for key, b in buckets.items():
            display = max(b["names"].items(), key=lambda kv: kv[1])[0]
            top = max(b["songs"], key=lambda s: (s.get("play_count") or 0))
            lang_counts = {}
            for s in b["songs"]:
                lg = normalize_language(s.get("language"))
                if lg:
                    lang_counts[lg] = lang_counts.get(lg, 0) + 1
            dominant = max(lang_counts.items(), key=lambda kv: kv[1])[0] if lang_counts else None
            doc = {
                "key": key,
                "name": display,
                "cover_art": top.get("cover_art") or top.get("thumbnail"),
                "song_count": len(b["songs"]),
                "album_count": len({s.get("album_key") for s in b["songs"] if s.get("album_key")}),
                "total_plays": sum(s.get("play_count", 0) or 0 for s in b["songs"]),
                "language": dominant,
            }
            self.artists[key] = doc
            toks = {}
            for t in tokenize(display):
                toks[t] = TITLE_W
            self.artist_tokens[key] = toks
            for t, w in toks.items():
                self.postings.setdefault(t, {})[f"ar:{key}"] = w

        # SymSpell delete-index + sorted vocab for prefix scan.
        for tok in self.postings:
            for d in _deletes(tok, _max_dist(tok)):
                self.deletes.setdefault(d, set()).add(tok)
        self.vocab = sorted(self.postings)

    # ---------------- query ----------------

    def _prefix_tokens(self, prefix):
        i = bisect.bisect_left(self.vocab, prefix)
        out = []
        while i < len(self.vocab) and self.vocab[i].startswith(prefix):
            out.append(self.vocab[i])
            if len(out) >= MAX_PREFIX_EXPANSIONS:
                break
            i += 1
        return out

    def _typo_tokens(self, token):
        """Vocabulary tokens within true edit distance (via delete-index)."""
        md = _max_dist(token)
        if md == 0:
            return {}
        cands = set()
        for d in _deletes(token, md):
            cands.update(self.deletes.get(d, ()))
        cands.discard(token)
        out = {}
        for c in cands:
            if abs(len(c) - len(token)) > md:
                continue
            dist = levenshtein(token, c, md)
            if dist <= md:
                out[c] = dist
        return out

    def _personal_boost(self, doc_id):
        boost = PLAY_W * math.log1p(
            (self.songs.get(doc_id) or {}).get("play_count", 0) or 0
        )
        if doc_id in self.liked:
            boost += LIKED_W
        ts = self.recent.get(doc_id)
        if ts:
            age_days = max(0.0, (time.time() - ts) / 86400.0)
            boost += RECENT_W * math.exp(-age_days / RECENT_HALF_LIFE_DAYS)
        return boost

    def _search_ids(self, query, limit, kinds=("song", "album", "artist")):
        qtokens = tokenize(query)
        if not qtokens:
            return []
        ckey = (kind_prefix(kinds), " ".join(qtokens), limit)
        hit = self._cached(ckey)
        if hit is not None:
            return hit

        scores = {}
        matched = {}
        for qt in qtokens:
            cands = {}  # token -> (kind, penalty)
            if qt in self.postings:
                cands[qt] = ("exact", 0)
            for pt in self._prefix_tokens(qt):
                if pt != qt:
                    cands.setdefault(pt, ("prefix", 0))
            for tt, dist in self._typo_tokens(qt).items():
                cands.setdefault(tt, ("typo", dist))
            for tok, (kind, dist) in cands.items():
                mult = EXACT_W if kind == "exact" else PREFIX_W if kind == "prefix" else TYPO_W * (1 - dist / (len(qt) + 1))
                for doc_id, w in self.postings.get(tok, {}).items():
                    dk = "album" if doc_id.startswith("al:") else "artist" if doc_id.startswith("ar:") else "song"
                    if dk not in kinds:
                        continue
                    key = (doc_id, dk)
                    add = w * mult
                    if add > scores.get(key, 0):
                        scores[key] = add
                    matched.setdefault(key, set()).add(qt)

        nq = len(qtokens)
        ranked = []
        for (doc_id, dk), text in scores.items():
            coverage = len(matched.get((doc_id, dk), ())) / nq
            score = text * (0.5 + 0.5 * coverage)
            if dk == "song":
                score += self._personal_boost(doc_id)
            ranked.append((score, dk, doc_id))
        ranked.sort(key=lambda t: (-t[0], t[2]))
        res = [(dk, doc_id) for _, dk, doc_id in ranked[:limit]]
        self._store(ckey, res)
        return res

    # ---------------- public API ----------------

    def search_songs(self, query, limit=20, language=None):
        lang = normalize_language(language)
        out = []
        for dk, doc_id in self._search_ids(query, limit * (3 if lang else 1), kinds=("song",)):
            s = self.songs.get(doc_id)
            if not s:
                continue
            if lang and normalize_language(s.get("language")) != lang:
                continue
            out.append(s)
            if len(out) >= limit:
                break
        return out

    def search_albums(self, query, limit=8):
        out = []
        for dk, doc_id in self._search_ids(query, limit, kinds=("album",)):
            a = self.albums.get(doc_id[3:])
            if a:
                out.append(a)
        return out

    def search_artists(self, query, limit=8, language=None):
        lang = normalize_language(language)
        out = []
        for dk, doc_id in self._search_ids(query, limit * (3 if lang else 1), kinds=("artist",)):
            a = self.artists.get(doc_id[3:])
            if not a:
                continue
            if lang and a.get("language") != lang:
                continue
            out.append(a)
            if len(out) >= limit:
                break
        return out

    def suggest(self, query, limit=8, language=None):
        """Lightweight autocomplete payload (id/title/artist only)."""
        lang = normalize_language(language)
        out = {"songs": [], "albums": [], "artists": []}
        for dk, doc_id in self._search_ids(query, limit * 3, kinds=("song", "album", "artist")):
            if dk == "song" and len(out["songs"]) < limit:
                s = self.songs.get(doc_id)
                if s and (not lang or normalize_language(s.get("language")) == lang):
                    out["songs"].append({"id": s["id"], "title": s.get("title"), "artist": s.get("artist"), "language": s.get("language")})
            elif dk == "album" and len(out["albums"]) < 3:
                a = self.albums.get(doc_id[3:])
                if a:
                    out["albums"].append({"id": a["id"], "name": a.get("name"), "artist": a.get("artist")})
            elif dk == "artist" and len(out["artists"]) < 3:
                a = self.artists.get(doc_id[3:])
                if a and (not lang or (a.get("language") or lang) == lang):
                    out["artists"].append({"key": a["key"], "name": a["name"], "language": a.get("language")})
            if len(out["songs"]) >= limit and len(out["albums"]) >= 3 and len(out["artists"]) >= 3:
                break
        return out

    # ---------------- result cache ----------------

    def _cached(self, key):
        hit = self._cache.get(key)
        if hit and time.time() - hit[0] < CACHE_TTL_S:
            self._cache.move_to_end(key)
            return hit[1]
        if hit:
            del self._cache[key]
        return None

    def _store(self, key, value):
        self._cache[key] = (time.time(), value)
        self._cache.move_to_end(key)
        while len(self._cache) > CACHE_MAX:
            self._cache.popitem(last=False)


def kind_prefix(kinds):
    return ",".join(sorted(kinds))


# ---------------- engine lifecycle (Mongo-backed) ----------------

_engine = SearchIndex()
_built_at = 0.0
_built_count = -1
_last_dirty_check = 0.0
_dirty = True


def mark_search_index_dirty():
    """Call after library mutations (scan/upload/delete) for prompt refresh."""
    global _dirty
    _dirty = True


async def _load_snapshot():
    """Single-pass snapshot: songs + albums + likes + recency."""
    from app.db.connection import songs_collection, albums_collection, history_collection
    from app.db.crud.songs import song_helper
    from app.db.connection import Database

    song_docs = []
    async for doc in songs_collection.find(
        {},
        projection={
            "title": 1, "artist": 1, "album": 1, "album_key": 1,
            "play_count": 1, "duration": 1, "cover_art": 1, "thumbnail": 1,
            "file_name": 1, "has_video": 1, "s3_audio_key": 1, "s3_video_key": 1,
            "telegram_message_id": 1, "year": 1, "genre": 1, "language": 1,
        },
    ):
        try:
            song_docs.append(song_helper(doc))
        except Exception:
            continue

    album_docs = []
    async for a in albums_collection.find(
        {}, projection={"name": 1, "artist": 1, "cover_art": 1, "song_ids": 1}
    ):
        album_docs.append(
            {
                "id": str(a["_id"]),
                "name": a.get("name"),
                "artist": a.get("artist"),
                "cover_art": a.get("cover_art"),
                "song_count": len(a.get("song_ids", []) or []),
            }
        )

    liked = []
    try:
        likes = Database.get_collection("likes")
        async for doc in likes.find({"liked": True}, projection={"song_id": 1}):
            liked.append(doc.get("song_id"))
    except Exception:
        pass

    recent = {}
    try:
        from datetime import datetime, timedelta, timezone
        since = datetime.now(timezone.utc) - timedelta(days=7)
        async for doc in history_collection.aggregate(
            [
                {"$match": {"played_at": {"$gte": since}}},
                {"$sort": {"played_at": -1}},
                {"$group": {"_id": "$song_id", "last": {"$first": "$played_at"}}},
            ]
        ):
            ts = doc.get("last")
            try:
                recent[doc["_id"]] = ts.timestamp() if hasattr(ts, "timestamp") else 0
            except Exception:
                continue
    except Exception:
        pass

    return song_docs, album_docs, liked, recent


async def get_engine():
    """Fresh engine, rebuilding when the library changed or aged out."""
    global _built_at, _built_count, _last_dirty_check, _dirty
    from app.db.connection import songs_collection

    now = time.time()
    rebuild = _dirty or (now - _built_at > INDEX_MAX_AGE_S)
    if not rebuild and now - _last_dirty_check > DIRTY_CHECK_MIN_S:
        _last_dirty_check = now
        try:
            count = await songs_collection.count_documents({})
            if count != _built_count:
                rebuild = True
        except Exception:
            pass
    if rebuild and _engine.songs:
        # Serve stale index if refresh fails; only force-build when empty.
        try:
            song_docs, album_docs, liked, recent = await _load_snapshot()
            _engine.build(song_docs, album_docs, liked, recent)
            _built_count = len(song_docs)
            _built_at = now
            _dirty = False
            _last_dirty_check = now
        except Exception:
            pass
    elif rebuild:
        song_docs, album_docs, liked, recent = await _load_snapshot()
        _engine.build(song_docs, album_docs, liked, recent)
        _built_count = len(song_docs)
        _built_at = now
        _dirty = False
        _last_dirty_check = now
    return _engine
