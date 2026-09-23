"""Tests for vocal-segment helpers + fusion policy (Steps 1/4, no model)."""

from app.services.vocal_lang import (
    canonical_for_vox,
    vocal_segments,
    weighted_posterior,
    top_language,
    resolve_language,
)


def test_canonical_mapping():
    assert canonical_for_vox("sa") == "Sanskrit"
    assert canonical_for_vox("TA") == "Tamil"
    assert canonical_for_vox("pa") == "Punjabi"  # VoxLingua spells it Panjabi
    assert canonical_for_vox("iw") == "Hebrew"
    assert canonical_for_vox("xx") is None
    assert canonical_for_vox(None) is None


def test_vocal_segments_silence_gating():
    # 10 frames @1s: quiet, loud x4, quiet, loud x3, quiet
    energy = [-50, -20, -20, -20, -20, -50, -25, -25, -25, -50]
    times = [float(i) for i in range(10)]
    segs = vocal_segments(energy, times)
    assert segs == [(1.0, 5.0), (6.0, 9.0)]


def test_vocal_segments_merges_short_gaps_and_drops_blips():
    energy = [-20, -20, -50, -20, -20, -50, -20]
    times = [float(i) for i in range(7)]
    segs = vocal_segments(energy, times, merge_gap=0.3)
    # 1s gap at t=2 does not merge; trailing lone frame is too short.
    assert segs == [(0.0, 2.0), (3.0, 5.0)]
    assert vocal_segments([-20], [0.0]) == []


def test_weighted_posterior_duration_weights():
    probs = weighted_posterior([
        ({"Tamil": 0.9, "Hindi": 0.1}, 10.0),
        ({"Hindi": 0.8, "Tamil": 0.2}, 10.0),
    ])
    assert abs(probs["Tamil"] - 0.55) < 1e-9
    assert abs(probs["Hindi"] - 0.45) < 1e-9
    assert weighted_posterior([]) == {}


def test_top_language_threshold():
    assert top_language({"Tamil": 0.3}, threshold=0.2) == ("Tamil", 0.3)
    assert top_language({"Tamil": 0.3}, threshold=0.5) == (None, 0.3)
    assert top_language({}, threshold=0.0) == (None, 0.0)


def test_resolve_language_policy():
    # Unlabeled + above threshold -> accept.
    assert resolve_language(None, "auto", "Tamil", 0.3) == ("Tamil", "auto:audio")
    # Manual labels are sacred.
    assert resolve_language("Hindi", "manual", "Tamil", 0.95) == (None, None)
    # Auto labels yield only to high-confidence disagreement.
    assert resolve_language("Hindi", "auto", "Tamil", 0.9) == ("Tamil", "auto:audio")
    assert resolve_language("Hindi", "auto", "Tamil", 0.5) == (None, None)
    # Agreement: no write needed.
    assert resolve_language("Tamil", "auto", "Tamil", 0.9) == (None, None)
    # Below threshold: abstain.
    assert resolve_language(None, "auto", "Tamil", 0.1) == (None, None)
