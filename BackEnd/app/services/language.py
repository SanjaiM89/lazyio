"""Language detection + language-query intent (Phase 2).

Spotify-style language handling, adapted to a self-hosted library:

- Every track gets ``language`` + ``language_source`` (``auto``|``manual``).
- Detection is script-first (Unicode blocks are high precision for Indian
  languages), with genre hints (Kollywood -> Tamil) as fallback. Latin
  script alone is *not* evidence — it cannot distinguish English from
  transliterated Tamil, so it yields ``None`` instead of a wrong label.
- ``parse_language_intent`` turns queries like "tamil songs" into a
  language filter for the search engine (the "language:ta" token idea).

Pure stdlib — covered by BackEnd/tests/test_language.py.
"""

import re

# Unicode block starts/ends (inclusive) mapped to canonical language names.
SCRIPT_RANGES = [
    (0x0B80, 0x0BFF, "Tamil"),
    (0x0C00, 0x0C7F, "Telugu"),
    (0x0C80, 0x0CFF, "Kannada"),
    (0x0D00, 0x0D7F, "Malayalam"),
    (0x0900, 0x097F, "Hindi"),  # Devanagari
    (0x0A00, 0x0A7F, "Punjabi"),  # Gurmukhi
    (0x0980, 0x09FF, "Bengali"),
    (0x0A80, 0x0AFF, "Gujarati"),
    (0x0B00, 0x0B7F, "Odia"),
    (0x0D80, 0x0DFF, "Sinhala"),
]

# Canonical names + accepted aliases (query tokens, metadata variants).
LANGUAGE_ALIASES = {
    "tamil": "Tamil", "ta": "Tamil",
    "hindi": "Hindi", "hi": "Hindi",
    "telugu": "Telugu", "te": "Telugu",
    "kannada": "Kannada", "kn": "Kannada",
    "malayalam": "Malayalam", "ml": "Malayalam",
    "punjabi": "Punjabi", "pa": "Punjabi",
    "bengali": "Bengali", "bn": "Bengali", "bangla": "Bengali",
    "gujarati": "Gujarati", "gu": "Gujarati",
    "odia": "Odia", "oriya": "Odia",
    "english": "English", "en": "English",
    "urdu": "Urdu", "ur": "Urdu",
    "sinhala": "Sinhala", "si": "Sinhala",
}

# Industry-genre hints; only used when script detection finds nothing.
GENRE_LANGUAGE_HINTS = {
    "kollywood": "Tamil",
    "tollywood": "Telugu",
    "mollywood": "Malayalam",
    "sandalwood": "Kannada",
    "bollywood": "Hindi",
}

def normalize_language(name) -> str | None:
    """Canonicalize a language label (or None when unknown)."""
    if not name:
        return None
    key = re.sub(r"[^a-z]+", "", str(name).lower())
    if not key:
        return None
    if key in LANGUAGE_ALIASES:
        return LANGUAGE_ALIASES[key]
    # Accept already-canonical names case-insensitively.
    for canonical in set(LANGUAGE_ALIASES.values()):
        if canonical.lower() == key:
            return canonical
    return None


def _script_counts(text: str) -> dict:
    counts = {}
    for ch in text or "":
        code = ord(ch)
        for lo, hi, lang in SCRIPT_RANGES:
            if lo <= code <= hi:
                counts[lang] = counts.get(lang, 0) + 1
                break
    return counts


def detect_language(title=None, artist=None, album=None, genre=None) -> tuple:
    """(language | None, detail) from metadata text.

    Majority non-Latin script wins (needs >= 2 script chars); otherwise
    genre hints; otherwise (None, reason). Latin script alone is never
    treated as evidence.
    """
    blob = " ".join(t or "" for t in (title, artist, album))
    counts = _script_counts(blob)
    if counts:
        best, n = max(counts.items(), key=lambda kv: kv[1])
        total = sum(counts.values())
        if n >= 2 and n / max(total, 1) >= 0.5:
            return best, f"script:{best.lower()}"
        if n >= 2:
            return best, f"script:{best.lower()}:mixed"
    if genre:
        g = str(genre).lower()
        for hint, lang in GENRE_LANGUAGE_HINTS.items():
            if hint in g:
                return lang, f"genre:{hint}"
    if counts:
        return None, "script:ambiguous"
    return None, "script:none"


def parse_language_intent(query: str) -> str | None:
    """Extract a language filter from queries like "tamil songs".

    Returns the canonical language when the query names exactly one
    language (fillers like "songs"/"music" ignored), else None.
    ("english pop" -> English; "tamil vs hindi" -> None.)
    """
    if not query:
        return None
    tokens = re.sub(r"[^a-z]+", " ", query.lower()).split()
    langs = {LANGUAGE_ALIASES[t] for t in tokens if t in LANGUAGE_ALIASES}
    if len(langs) == 1:
        return next(iter(langs))
    return None
