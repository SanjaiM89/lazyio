"""Tests for language detection + query intent (Phase 2)."""

from app.services.language import (
    detect_language,
    detect_from_lyrics,
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
    # Unknown artist + plain Latin text: nothing to go on.
    lang, detail = detect_language("Mystery Track", "Unknown Singer", "Misc")
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


def test_lyrics_detection_needs_sustained_script():
    tamil_lyrics = "காதல் வைரஸ் பரவும் நேரம்\n" * 10
    lang, _ = detect_from_lyrics(tamil_lyrics)
    assert lang == "Tamil"


def test_lyrics_too_short_or_mixed():
    assert detect_from_lyrics("hello")[0] is None
    mixed = ("காதல் " * 5) + ("hello world " * 30)
    assert detect_from_lyrics(mixed)[0] is None


def test_sanskrit_intent_and_keywords():
    assert parse_language_intent("sanskrit songs") == "Sanskrit"
    assert parse_language_intent("marathi songs") == "Marathi"
    assert parse_language_intent("nepali music") == "Nepali"
    lang, detail = detect_language("Vishnu Sahasranamam", "M. S. Subbulakshmi")
    assert lang == "Sanskrit"  # Transliterated Sanskrit keyword detected
    lang, detail = detect_language("विष्णु सहस्रनामम्", "Singer", genre="Sanskrit")
    assert lang == "Sanskrit"


def test_genre_hints_cover_transliterated_catalogs():
    assert detect_language("Hukum", "Anirudh", genre="Tamil Pop")[0] == "Tamil"
    assert detect_language("Tum Hi Ho", "Arijit", genre="Hindi Film")[0] == "Hindi"
    assert detect_language("Some Song", "Someone", genre="Punjabi Hits")[0] == "Punjabi"


def test_cjk_disambiguation():
    # Kanji + hiragana reads Japanese even when ideographs dominate.
    lang, _ = detect_language("千本桜せんぼんざくら", "Artist")
    assert lang == "Japanese"
    lang, _ = detect_language("사랑해요", "Artist")
    assert lang == "Korean"
    lang, _ = detect_language("月亮代表我的心", "Artist")
    assert lang == "Chinese"
    lang, _ = detect_language("สวัสดี", "Artist")
    assert lang == "Thai"


def test_normalize_new_languages():
    assert normalize_language("sanskrit") == "Sanskrit"
    assert normalize_language("marathi") == "Marathi"
    assert normalize_language("japanese") == "Japanese"
    assert normalize_language("arabic") == "Arabic"


def test_artist_hints_label_latin_catalogs():
    assert detect_language("Hukum", "Anirudh Ravichander", "Jailer")[0] == "Tamil"
    assert detect_language("Blinding Lights", "The Weeknd")[0] == "English"
    assert detect_language("Tum Hi Ho", "Arijit Singh")[0] == "Hindi"
    assert detect_language("Kesariya", "A.R. Rahman")[0] is None  # ambiguous: no auto-label


def test_script_beats_artist_hint():
    # Devanagari title wins over a Tamil-hint artist tag.
    lang, detail = detect_language("तुम ही हो", "Anirudh Ravichander")
    assert lang == "Hindi"
