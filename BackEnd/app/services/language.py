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
# NOTE: some scripts cover several languages (Devanagari -> Hindi/Marathi/
# Nepali/Sanskrit, Arabic script -> Arabic/Urdu/Persian). Those resolve via
# keyword/genre hints below; the bare script maps to the majority label or
# to None when guessing would be reckless (see detect_language).
SCRIPT_RANGES = [
    (0x0B80, 0x0BFF, "Tamil"),
    (0x0C00, 0x0C7F, "Telugu"),
    (0x0C80, 0x0CFF, "Kannada"),
    (0x0D00, 0x0D7F, "Malayalam"),
    (0x0900, 0x097F, "Hindi"),  # Devanagari (see keyword overrides)
    (0x0A00, 0x0A7F, "Punjabi"),  # Gurmukhi
    (0x0980, 0x09FF, "Bengali"),
    (0x0A80, 0x0AFF, "Gujarati"),
    (0x0B00, 0x0B7F, "Odia"),
    (0x0D80, 0x0DFF, "Sinhala"),
    (0x0E00, 0x0E7F, "Thai"),
    (0x0370, 0x03FF, "Greek"),
    (0x0590, 0x05FF, "Hebrew"),
    (0x0530, 0x058F, "Armenian"),
    (0x10A0, 0x10FF, "Georgian"),
    (0x0400, 0x04FF, "Russian"),  # Cyrillic (majority label; override manually)
    (0x3040, 0x309F, "Japanese"),  # Hiragana
    (0x30A0, 0x30FF, "Japanese"),  # Katakana
    (0xAC00, 0xD7AF, "Korean"),  # Hangul
    (0x4E00, 0x9FFF, "Chinese"),  # CJK ideographs (no kana/hangul present)
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
    "sanskrit": "Sanskrit", "sa": "Sanskrit",
    "marathi": "Marathi", "mr": "Marathi",
    "nepali": "Nepali", "ne": "Nepali",
    "assamese": "Assamese", "as": "Assamese",
    "arabic": "Arabic", "ar": "Arabic",
    "persian": "Persian", "farsi": "Persian", "fa": "Persian",
    "chinese": "Chinese", "zh": "Chinese", "mandarin": "Chinese",
    "japanese": "Japanese", "ja": "Japanese",
    "korean": "Korean", "ko": "Korean",
    "thai": "Thai", "th": "Thai",
    "french": "French", "fr": "French",
    "german": "German", "de": "German",
    "spanish": "Spanish", "es": "Spanish",
    "portuguese": "Portuguese", "pt": "Portuguese",
    "italian": "Italian", "it": "Italian",
    "russian": "Russian", "ru": "Russian",
    "greek": "Greek", "el": "Greek",
    "hebrew": "Hebrew", "he": "Hebrew",
    "malay": "Malay", "ms": "Malay",
    "indonesian": "Indonesian", "id": "Indonesian",
    "turkish": "Turkish", "tr": "Turkish",
    "vietnamese": "Vietnamese", "vi": "Vietnamese",
}

# Industry-genre hints; only used when script detection finds nothing.
# Latin-script genre tags ("Tamil Pop") are the main way transliterated
# catalogs get labeled, so this map is intentionally broad.
GENRE_LANGUAGE_HINTS = {
    "kollywood": "Tamil", "tamil": "Tamil",
    "tollywood": "Telugu", "telugu": "Telugu",
    "mollywood": "Malayalam", "malayalam": "Malayalam",
    "sandalwood": "Kannada", "kannada": "Kannada",
    "bollywood": "Hindi", "hindi": "Hindi",
    "punjabi": "Punjabi", "bengali": "Bengali", "bangla": "Bengali",
    "gujarati": "Gujarati", "odia": "Odia", "oriya": "Odia",
    "english": "English", "urdu": "Urdu",
    "sanskrit": "Sanskrit", "marathi": "Marathi", "nepali": "Nepali",
    "assamese": "Assamese", "arabic": "Arabic",
    "persian": "Persian", "farsi": "Persian",
}

# Well-known artists with an unambiguous primary language, normalized
# ("anirudh ravichander" -> "anirudhravichander"). Substring-matched
# against the normalized artist tag. Deliberately EXCLUDES multilingual
# artists (A.R. Rahman, Sid Sriram, Shreya Ghoshal...) — those resolve
# via propagation/manual instead of a wrong auto-label.
ARTIST_LANGUAGE_HINTS = {
    # Tamil film music
    "anirudhravichander": "Tamil", "anirudh": "Tamil",
    "yuvanshankarraja": "Tamil", "yuvan": "Tamil",
    "harrisjayaraj": "Tamil", "harris": "Tamil",
    "dimman": "Tamil", "imman": "Tamil",
    "ghibran": "Tamil",
    "santhoshnarayanan": "Tamil",
    "seanroldan": "Tamil",
    "govindvasantha": "Tamil",
    "justinprabhakaran": "Tamil",
    "leonjames": "Tamil",
    "hiphoptamizha": "Tamil",
    "ilaiyaraaja": "Tamil", "ilayaraja": "Tamil",
    "madankarky": "Tamil", "yugabharathi": "Tamil", "viveklyricist": "Tamil",
    # Hindi film music
    "arijitsingh": "Hindi", "arijit": "Hindi",
    "pritam": "Hindi",
    "vishalshekhar": "Hindi",
    "amitrivedi": "Hindi",
    "nehakakkar": "Hindi", "neha": "Hindi",
    "badshah": "Hindi",
    "honeysingh": "Hindi", "yoyohoneysingh": "Hindi",
    "alkayagnik": "Hindi",
    "kumarsanu": "Hindi",
    "uditnarayan": "Hindi",
    "shankarmahadevan": "Hindi",
    "sukhwindersingh": "Hindi",
    # Telugu film music
    "devisriprasad": "Telugu", "dsp": "Telugu",
    "thamans": "Telugu", "thaman": "Telugu",
    "mmkeeravani": "Telugu", "keeravani": "Telugu",
    # Punjabi
    "diljitdosanjh": "Punjabi", "diljit": "Punjabi",
    "apdhillon": "Punjabi",
    "gurdasmaan": "Punjabi",
    "jassmanak": "Punjabi",
    # English-language pop
    "taylorswift": "English",
    "theweeknd": "English", "weeknd": "English",
    "edsheeran": "English",
    "eminem": "English",
    "davidguetta": "English", "guetta": "English",
    "adele": "English",
    "coldplay": "English",
    "imaginedragons": "English",
}

# Extended Sanskrit keywords in Latin script for transliterated titles/lyrics
SANSKRIT_KEYWORDS = {
    "sanskrit", "shloka", "sloka", "stotram", "stotra", "stotras",
    "sahasranamam", "ashtakam", "ashtottaram", "vedic", "mantra", "mantram",
    "suktam", "kavacham", "gayatri", "suprabhatam", "lahari", "trishati",
    "bhujangam", "namavali", "chalisa", "tripath", "sahasra",
}

# Native-script substrings with the same job (sandhi compounds included,
# e.g. विष्णुसहस्रनामम् contains सहस्रनाम).
DEVANAGARI_SANSKRIT_SUBSTRINGS = {
    "सहस्रनाम", "स्तोत्र", "स्तोत्रम्", "श्लोक", "मंत्र", "मन्त्र",
    "गायत्री", "गायत्रि", "सूक्त", "कवच", "अष्टक", "वैदिक", "संस्कृत",
    "सहस्र", "लहरी", "त्रिशती", "भुजंगम", "नामावली", "चालीसा",
}

# Transliterated Tamil keywords for titles/genres
TAMIL_KEYWORDS = {
    "tamil", "thamizhan", "paadal", "padal", "paadaltgal", "kavithai",
    "thaalattu", "kavasam", "vanakkam", "kollywood", "isai", "kaadhal",
    "kadal", "ponniyin",
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

    Majority non-Latin script wins (needs >= 2 script chars), with disambiguations
    and transliteration keywords for Latin-script metadata.
    """
    blob = " ".join(t or "" for t in (title, artist, album))
    counts = _script_counts(blob)
    words = set(re.sub(r"[^a-z]+", " ", blob.lower()).split())
    norm_artist = re.sub(r"[^a-z0-9]+", " ", (artist or "").lower())
    norm_artist_key = re.sub(r"[^a-z0-9]", "", norm_artist)

    if counts.get("Japanese", 0) >= 2 or counts.get("Korean", 0) >= 2:
        # Unambiguous markers beat ideograph counts.
        if counts.get("Japanese", 0) >= counts.get("Korean", 0):
            return "Japanese", "script:kana"
        return "Korean", "script:hangul"

    devanagari = sum(1 for ch in blob if 0x0900 <= ord(ch) <= 0x097F)
    if devanagari >= 2 and (
        words & SANSKRIT_KEYWORDS
        or any(s in blob for s in DEVANAGARI_SANSKRIT_SUBSTRINGS)
    ):
        return "Sanskrit", "script:sanskrit-keywords"

    if counts:
        best, n = max(counts.items(), key=lambda kv: kv[1])
        total = sum(counts.values())
        if n >= 2 and n / max(total, 1) >= 0.5:
            return best, f"script:{best.lower()}"
        if n >= 2:
            return best, f"script:{best.lower()}:mixed"

    # Transliterated Sanskrit detection (Latin script keywords in title or album)
    title_album_words = set(re.sub(r"[^a-z]+", " ", f"{title or ''} {album or ''}".lower()).split())
    title_album_blob = f"{title or ''} {album or ''}".lower()
    if title_album_words & SANSKRIT_KEYWORDS or any(kw in title_album_blob for kw in ("sahasranamam", "stotram", "stotra", "ashtakam", "kavacham", "suprabhatam", "shloka", "sloka", "stotras", "mantra")):
        return "Sanskrit", "transliteration:sanskrit-keyword"

    # Transliterated Tamil detection (Latin script keywords)
    if words & TAMIL_KEYWORDS or any(kw in title_album_blob for kw in ("tamil", "kollywood", "paadal", "padal", "kavasa")):
        return "Tamil", "transliteration:tamil-keyword"

    for hint_key, lang in ARTIST_LANGUAGE_HINTS.items():
        if hint_key and hint_key in norm_artist_key:
            return lang, f"artist:{hint_key}"

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


def detect_from_lyrics(plain_text: str, min_chars: int = 20) -> tuple:
    """Detect language from lyrics body text (strong signal).

    Needs a sustained run of one script (>= ``min_chars`` script+Latin
    chars and >= 60% share) so a single English interlude line can't
    flip the label — and Latin-heavy bodies stay unlabeled.
    """
    text = plain_text or ""
    counts = _script_counts(text)
    latin = len(re.findall(r"[A-Za-z]", text))
    total = sum(counts.values()) + latin
    if total < min_chars:
        return None, "lyrics:too-short"
    if counts.get("Japanese", 0) >= 2 or counts.get("Korean", 0) >= 2:
        markers = counts.get("Japanese", 0) + counts.get("Korean", 0)
        if markers / total >= 0.15:
            if counts.get("Japanese", 0) >= counts.get("Korean", 0):
                return "Japanese", "lyrics:kana"
            return "Korean", "lyrics:hangul"
    if not counts:
        return None, "lyrics:latin-only"
    best, n = max(counts.items(), key=lambda kv: kv[1])
    if n / total >= 0.6:
        return best, f"lyrics:{best.lower()}"
    return None, "lyrics:mixed"
