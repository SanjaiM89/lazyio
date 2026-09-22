"""Tests for audio-feature math (Phase 1, numpy only — no audio files)."""

import pytest

np = pytest.importorskip("numpy")

from app.services.audio_analysis import (
    instrumentalness_from_spectrogram,
    valence_from_chroma,
    lofi_score_from_stats,
    is_lofi_track,
    features_to_vector,
)


def test_instrumentalness_silent_vocal_band_is_one():
    S = np.zeros((100, 10))
    S[:2, :] = 5.0  # 0-222 Hz: below the vocal band only
    freqs = np.linspace(0, 11025, 100)
    assert instrumentalness_from_spectrogram(S, freqs) == 1.0


def test_instrumentalness_vocal_heavy_is_low():
    S = np.zeros((100, 10))
    S[10:40, :] = 5.0  # ~1100-4400 Hz band dominates
    freqs = np.linspace(0, 11025, 100)
    assert instrumentalness_from_spectrogram(S, freqs) < 0.3


def test_valence_major_vs_minor():
    major = np.array([1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0], dtype=float)
    minor = np.array([1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0], dtype=float)
    assert valence_from_chroma(major) > 0.6
    assert valence_from_chroma(minor) < 0.4
    assert valence_from_chroma(None) == 0.5


def test_lofi_stats_and_gate():
    score = lofi_score_from_stats(flatness=0.02, centroid_hz=2000, dyn_range=0.2)
    assert score > 0.4
    clean = lofi_score_from_stats(flatness=0.0005, centroid_hz=8000, dyn_range=2.0)
    assert clean < 0.2
    assert is_lofi_track(80, 0.9, 0.6) is True
    assert is_lofi_track(128, 0.9, 0.6) is False  # tempo out of band
    assert is_lofi_track(80, 0.2, 0.6) is False  # vocal


def test_vector_dim_and_ranges():
    f = {
        "bpm": 128, "danceability": 0.7, "energy": 0.8,
        "instrumentalness": 0.1, "lofi_score": 0.0, "valence": 0.6,
        "mfcc": list(range(13)),
    }
    v = features_to_vector(f)
    assert len(v) == 19
    assert abs(v[0] - 0.64) < 1e-6
    assert all(isinstance(x, float) for x in v)
