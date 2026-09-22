"""Tests for language detection + query intent (Phase 2)."""

from app.services.language import (
    detect_language,
    parse_language_intent,
    normalize_language,
)


def test_normalize_variants():
    assert normalize_language("Tamil") == "Tamil"
    assert normalize_language("tamil ") == "Tamil"
    assert normalize_language("ta") == "Tamil"
    assert normalize_language("EN") == "English"
    assert normalize_language("Klingon") is None
    assert normalize_language("") is None
    assert normalize_language(None) is None


def test_tamil_script_detection():
    lang, detail = detect_language("காதல் வைரஸ்", "Anirudh Ravichander")
    assert lang == "Tamil"
    assert detail.startswith("script:")


def test_devanagari_detection():
    lang, detail = detect_language("तुम ही हो", "Arijit Singh")
    assert lang == "Hindi"
    assert detail.startswith("script:")


def test_latin_is_not_evidence():
    lang, detail = detect_language("Hukum", "Anirudh Ravichander", "Jailer")
    assert lang is None
    assert detail == "script:none"


def test_genre_hint_fallback():
    assert detect_language("Ordinary Song", "Someone", genre="Kollywood")[0] == "Tamil"
    assert detect_language("Ordinary Song", "Someone", genre="Bollywood Dance")[0] == "Hindi"
    assert detect_language("Ordinary Song", "Someone", genre="Pop")[0] is None


def test_intent_single_language():
    assert parse_language_intent("tamil songs") == "Tamil"
    assert parse_language_intent("Tamil") == "Tamil"
    assert parse_language_intent("english pop") == "English"
    assert parse_language_intent("lofi hindi mix") == "Hindi"


def test_intent_ambiguous_or_empty():
    assert parse_language_intent("tamil vs hindi") is None
    assert parse_language_intent("namaste") is None
    assert parse_language_intent("") is None
    assert parse_language_intent("songs") is None
