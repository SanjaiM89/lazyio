"""Tests for language-filtered search + graceful fallback (Phase 2).

SearchIndex is pure in-memory: build from plain dicts, no DB needed.
"""

from app.db.crud.search_engine import SearchIndex


def _index():
    idx = SearchIndex()
    idx.build(
        [
            {"id": "t1", "title": "Tamil Love Song", "artist": "A", "album": "X", "language": "Tamil"},
            {"id": "t2", "title": "Love Memories", "artist": "B", "album": "Y", "language": "Tamil"},
            {"id": "e1", "title": "Love Story", "artist": "C", "album": "Z", "language": "English"},
            {"id": "u1", "title": "Lovely Night", "artist": "D", "album": "W"},
            {"id": "u2", "title": "Endless Love", "artist": "E", "album": "V"},
        ],
        [],
    )
    return idx


def test_language_filter_excludes_other_languages():
    idx = _index()
    ids = [s["id"] for s in idx.search_songs("love", limit=10, language="Tamil")]
    assert "t1" in ids and "t2" in ids
    assert "e1" not in ids  # confidently English stays out


def test_fallback_pads_with_unlabeled():
    idx = _index()
    ids = [s["id"] for s in idx.search_songs("love", limit=10, language="Tamil")]
    assert "u1" in ids or "u2" in ids  # unlabeled fill the gaps


def test_no_filter_returns_everything_ranked():
    idx = _index()
    ids = [s["id"] for s in idx.search_songs("love", limit=10)]
    assert set(ids) == {"t1", "t2", "e1", "u1", "u2"}


def test_unknown_language_behaves_unfiltered():
    idx = _index()
    ids = [s["id"] for s in idx.search_songs("love", limit=10, language="Klingon")]
    assert set(ids) == {"t1", "t2", "e1", "u1", "u2"}  # unresolvable = no filter


def test_offset_paginates_without_overlap():
    idx = _index()
    page1 = [s["id"] for s in idx.search_songs("love", limit=2)]
    page2 = [s["id"] for s in idx.search_songs("love", limit=2, offset=2)]
    assert len(page1) == 2 and len(page2) == 2
    assert not set(page1) & set(page2)
    page3 = [s["id"] for s in idx.search_songs("love", limit=2, offset=4)]
    assert len(page3) == 1
    assert not set(page1 + page2) & set(page3)


def test_offset_with_language_filter():
    idx = _index()
    page1 = [s["id"] for s in idx.search_songs("love", limit=2, language="Tamil")]
    page2 = [s["id"] for s in idx.search_songs("love", limit=2, language="Tamil", offset=2)]
    assert "e1" not in page1 + page2
    assert not set(page1) & set(page2)


def test_language_first_finds_script_titled_songs():
    # Tamil-script title: zero Latin tokens, invisible to text matching,
    # but labeled Tamil -> must surface for "tamil songs" (WHERE lang
    # first, then rank — the Spotify order).
    idx = SearchIndex()
    idx.build(
        [
            {"id": "s1", "title": "காதல் வைரஸ்", "artist": "Anirudh", "language": "Tamil"},
            {"id": "e1", "title": "Love Story", "artist": "C", "album": "Z", "language": "English"},
            {"id": "u1", "title": "Mystery Track", "artist": "D"},
        ],
        [],
    )
    ids = [s["id"] for s in idx.search_songs("tamil songs", limit=10, language="Tamil")]
    assert "s1" in ids
    assert "e1" not in ids
