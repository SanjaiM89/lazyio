"""Tests for taste-profile engagement weights (Phase 4, no DB needed)."""

from app.db.crud.profile import weight_for_completion


def test_completion_rewards():
    assert weight_for_completion(1.0) == 1.0
    assert weight_for_completion(0.8) == 1.0


def test_skip_penalizes():
    assert weight_for_completion(0.2) == -0.5
    assert weight_for_completion(0.0) == -0.5


def test_passive_counts_a_little():
    assert weight_for_completion(0.5) == 0.2


def test_garbage_is_neutral():
    assert weight_for_completion(None) == 0.0
    assert weight_for_completion("x") == 0.0
