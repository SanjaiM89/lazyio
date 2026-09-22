"""Tests for hybrid recommendation math (Phase 3, stdlib only)."""

from datetime import datetime, timedelta, timezone

from app.services.reco import (
    segment_sessions,
    count_transitions,
    minmax_normalize,
    merge_hybrid,
)

NOW = datetime.now(timezone.utc)


def test_sessions_split_on_gap():
    events = [
        ("a", NOW),
        ("b", NOW + timedelta(minutes=5)),
        ("c", NOW + timedelta(hours=2)),  # gap -> new session
        ("d", NOW + timedelta(hours=2, minutes=1)),
    ]
    assert segment_sessions(events) == [["a", "b"], ["c", "d"]]


def test_sessions_unsorted_and_blank_ids():
    events = [
        ("b", NOW + timedelta(minutes=5)),
        ("", NOW + timedelta(minutes=6)),
        ("a", NOW),
    ]
    assert segment_sessions(events) == [["a", "b"]]


def test_transition_counts_skip_self_loops():
    sessions = [["a", "b", "b", "c"], ["b", "c"], ["c", "a"]]
    t = count_transitions(sessions)
    assert t["a"] == {"b": 1}
    assert t["b"] == {"c": 2}
    assert t["c"] == {"a": 1}


def test_minmax_normalize_scales_to_weight():
    items = [{"id": "a", "score": 10.0}, {"id": "b", "score": 20.0}]
    out = minmax_normalize(items, "score", 0.5)
    assert out[0]["normalized_score"] == 0.0
    assert out[1]["normalized_score"] == 0.5


def test_minmax_normalize_equal_scores():
    items = [{"id": "a", "score": 3.0}, {"id": "b", "score": 3.0}]
    out = minmax_normalize(items, "score", 0.5)
    assert all(r["normalized_score"] == 0.5 for r in out)
    assert minmax_normalize([], "score") == []


def test_merge_prefers_overlap_then_orders():
    vector = [
        {"id": "a", "normalized_score": 0.5},
        {"id": "b", "normalized_score": 0.4},
    ]
    behav = [
        {"id": "b", "normalized_score": 0.5},
        {"id": "c", "normalized_score": 0.1},
    ]
    merged = merge_hybrid(vector, behav, limit=3)
    assert [t["id"] for t in merged] == ["b", "a", "c"]
    assert merged[0]["final_score"] == 0.9
