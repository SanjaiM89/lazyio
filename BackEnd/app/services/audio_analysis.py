"""Spotify-style audio analysis for Lazyio (Phase 1).

Computes per-track descriptors with librosa (pure pip wheels — no system
libraries beyond the ffmpeg the Docker image already ships):

- ``bpm``               tempo via beat tracking (lo-fi lives ~70-95 BPM)
- ``instrumentalness``  0..1, inverse vocal-band (300-3400 Hz) energy ratio
- ``lofi_score``        0..1 heuristic from spectral flatness (hiss/crackle),
                        low spectral centroid (muffled) and compressed dynamics
- ``energy``            mean RMS loudness
- ``valence``           0..1 major-vs-minor chroma match (happy <-> sad proxy)
- ``danceability``      percussive regularity proxy from onset strength
- ``mfcc``              13 mean MFCCs (timbre fingerprint for similarity)
- ``dmfcc``             13 mean delta-MFCCs (timbre *change*; Step 2 upgrade)

NOTE (Step 2 scope): the paper's full GMM-codebook histogram needs a
persisted corpus-level codebook + refit/versioning infra. Mean + delta
MFCCs capture most of its value at zero infra cost, so the codebook
stays deferred until similarity quality demands it.

Only the first ``ANALYZE_SECONDS`` of audio are decoded, so analysis stays
bounded (~5-20 s CPU per track) even for long files.

Public API:
- ``analyze_file(path)`` -> feature dict | None (never raises)
- ``features_to_vector(features)`` -> 19-dim float list for FAISS
- pure helpers (``instrumentalness_from_spectrogram`` etc.) are numpy-only
  and covered by BackEnd/tests/test_audio_features.py.
"""

import logging
import os
import subprocess
import tempfile

logger = logging.getLogger("AudioAnalysis")

try:
    import numpy as np

    NUMPY_AVAILABLE = True
except ImportError:  # pragma: no cover
    np = None
    NUMPY_AVAILABLE = False

try:
    import librosa

    LIBROSA_AVAILABLE = True
except ImportError:
    librosa = None
    LIBROSA_AVAILABLE = False

ANALYZER_VERSION = "librosa-v2"
ANALYZE_SECONDS = 75
ANALYZE_SR = 22050
VECTOR_DIM = 32  # 6 scalars + 13 MFCC means + 13 delta-MFCC means

VOCAL_LOW_HZ = 300.0
VOCAL_HIGH_HZ = 3400.0
LOFI_BPM_LOW = 70.0
LOFI_BPM_HIGH = 95.0


def _clip01(x: float) -> float:
    try:
        v = float(x)
    except (TypeError, ValueError):
        return 0.0
    if v != v:  # NaN
        return 0.0
    return max(0.0, min(1.0, v))


# ---------------------------------------------------------------------------
# Pure (numpy-only) feature math — unit tested, no audio I/O.
# ---------------------------------------------------------------------------

def instrumentalness_from_spectrogram(S, freqs) -> float:
    """1.0 = almost certainly instrumental, 0.0 = strongly vocal.

    ``S`` is a magnitude spectrogram, ``freqs`` the matching bin frequencies.
    """
    if not NUMPY_AVAILABLE or S is None or freqs is None:
        return 0.0
    try:
        total = float(np.sum(S)) + 1e-10
        mask = (freqs >= VOCAL_LOW_HZ) & (freqs <= VOCAL_HIGH_HZ)
        vocal_ratio = float(np.sum(S[mask, :])) / total
        return _clip01(1.0 - vocal_ratio * 2.5)
    except Exception:
        return 0.0


def valence_from_chroma(chroma_mean) -> float:
    """Major-vs-minor template match over all 12 roots -> 0..1."""
    if not NUMPY_AVAILABLE or chroma_mean is None:
        return 0.5
    try:
        c = np.asarray(chroma_mean, dtype=float)
        if c.shape != (12,):
            return 0.5
        major = np.array([1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0], dtype=float)
        minor = np.array([1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0], dtype=float)

        def corr(a, b):
            a = a - a.mean()
            b = b - b.mean()
            denom = (np.linalg.norm(a) * np.linalg.norm(b)) + 1e-10
            return float(np.dot(a, b) / denom)

        best_major = max(corr(np.roll(c, -r), major) for r in range(12))
        best_minor = max(corr(np.roll(c, -r), minor) for r in range(12))
        return _clip01((best_major - best_minor + 1.0) / 2.0)
    except Exception:
        return 0.5


def lofi_score_from_stats(flatness: float, centroid_hz: float, dyn_range: float) -> float:
    """Heuristic 0..1: hiss/crackle + muffled top end + squashed dynamics."""
    try:
        hiss = _clip01((float(flatness) - 0.002) / 0.02)
        muffled = _clip01((4000.0 - float(centroid_hz)) / 4000.0)
        squashed = _clip01((0.6 - float(dyn_range)) / 0.6)
        return _clip01(0.5 * hiss + 0.3 * muffled + 0.2 * squashed)
    except (TypeError, ValueError):
        return 0.0


def is_lofi_track(bpm: float, instrumentalness: float, lofi_score: float) -> bool:
    return (
        LOFI_BPM_LOW <= float(bpm or 0) <= LOFI_BPM_HIGH
        and float(instrumentalness or 0) > 0.5
        and float(lofi_score or 0) > 0.35
    )


def features_to_vector(f: dict) -> list:
    """32-dim FAISS vector: 6 normalized scalars + MFCC + delta-MFCC."""
    mfcc = _pad13(f.get("mfcc"))
    dmfcc = _pad13(f.get("dmfcc"))
    vec = [
        _clip01(float(f.get("bpm") or 0) / 200.0),
        _clip01(f.get("danceability") or 0),
        _clip01(f.get("energy") or 0),
        _clip01(f.get("instrumentalness") or 0),
        _clip01(f.get("lofi_score") or 0),
        _clip01(f.get("valence") if f.get("valence") is not None else 0.5),
    ]
    vec.extend([_norm_mfcc(v) for v in mfcc])
    vec.extend([_norm_mfcc(v) for v in dmfcc])
    return [float(v) for v in vec]


def _pad13(vals) -> list:
    vals = list(vals or [])
    return (vals + [0.0] * 13)[:13]


def _norm_mfcc(v) -> float:
    if NUMPY_AVAILABLE:
        return float(np.clip(float(v or 0.0) / 100.0, -1.0, 1.0))
    return 0.0


# ---------------------------------------------------------------------------
# File analysis (needs librosa + ffmpeg; never raises).
# ---------------------------------------------------------------------------

def _decode_prefix_to_wav(src_path: str, seconds: int = ANALYZE_SECONDS) -> str | None:
    """Decode the head of *src_path* to a temp mono WAV via ffmpeg.

    Works for full files and truncated prefixes alike (best effort).
    Returns the temp path or None.
    """
    try:
        fd, dst = tempfile.mkstemp(prefix="lazyio-an-", suffix=".wav")
        os.close(fd)
        cmd = [
            "ffmpeg", "-v", "error", "-y",
            "-i", src_path,
            "-t", str(seconds),
            "-ar", str(ANALYZE_SR), "-ac", "1",
            "-f", "wav", dst,
        ]
        subprocess.run(cmd, timeout=120, check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(dst) and os.path.getsize(dst) > 4096:
            return dst
        try:
            os.remove(dst)
        except OSError:
            pass
        return None
    except Exception as e:
        logger.warning(f"ffmpeg decode failed for {src_path}: {e}")
        return None


def analyze_file(path: str, max_seconds: int = ANALYZE_SECONDS) -> dict | None:
    """Analyze an audio file -> feature dict, or None when unavailable.

    Never raises: missing libs, undecodable files and short clips all
    return None so background jobs can skip and continue.
    """
    if not NUMPY_AVAILABLE or not LIBROSA_AVAILABLE:
        return None
    if not path or not os.path.exists(path):
        return None
    try:
        wav = _decode_prefix_to_wav(path, seconds=max_seconds)
        if wav:
            try:
                y, sr = librosa.load(wav, sr=ANALYZE_SR, mono=True)
            finally:
                try:
                    os.remove(wav)
                except OSError:
                    pass
        else:
            y, sr = librosa.load(path, sr=ANALYZE_SR, mono=True, duration=max_seconds)
        if y is None or len(y) < sr:
            return None

        tempo, _beats = librosa.beat.beat_track(y=y, sr=sr)
        if isinstance(tempo, np.ndarray):
            tempo = float(tempo[0]) if len(tempo) else 0.0
        bpm = float(tempo or 0.0)

        S = np.abs(librosa.stft(y, n_fft=2048))
        freqs = librosa.fft_frequencies(sr=sr)
        instrumentalness = instrumentalness_from_spectrogram(S, freqs)

        flat = librosa.feature.spectral_flatness(y=y)
        flatness = float(np.mean(flat))
        cent = librosa.feature.spectral_centroid(y=y, sr=sr)
        centroid = float(np.mean(cent))
        rms = librosa.feature.rms(y=y)[0]
        rms_mean = float(np.mean(rms)) + 1e-10
        dyn_range = float(np.std(rms) / rms_mean)
        energy = _clip01(rms_mean * 4.0)
        lofi_score = lofi_score_from_stats(flatness, centroid, dyn_range)

        chroma = librosa.feature.chroma_stft(y=y, sr=sr)
        valence = valence_from_chroma(np.mean(chroma, axis=1))

        onset = librosa.onset.onset_strength(y=y, sr=sr)
        danceability = _clip01(float(np.mean(onset)) / (float(np.max(onset)) + 1e-6) * 2.0)

        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        mfcc_mean = [float(v) for v in np.mean(mfcc, axis=1)]
        dmfcc = librosa.feature.delta(mfcc)
        dmfcc_mean = [float(v) for v in np.mean(dmfcc, axis=1)]

        features = {
            "bpm": round(bpm, 2),
            "instrumentalness": round(instrumentalness, 3),
            "is_instrumental": bool(instrumentalness > 0.7),
            "lofi_score": round(lofi_score, 3),
            "is_lofi": bool(is_lofi_track(bpm, instrumentalness, lofi_score)),
            "energy": round(energy, 3),
            "valence": round(valence, 3),
            "danceability": round(danceability, 3),
            "mfcc": [round(v, 3) for v in mfcc_mean],
            "dmfcc": [round(v, 3) for v in dmfcc_mean],
            "analyzer": ANALYZER_VERSION,
        }
        return features
    except Exception as e:
        logger.warning(f"analysis failed for {path}: {e}")
        return None
