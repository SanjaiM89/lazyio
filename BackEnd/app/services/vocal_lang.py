"""Singing-language ID from vocal segments (Phase 1, paper §3.1.2).

Pipeline (Lee et al., adapted to zero-training-data operation):

1. Decode the track head and isolate *voiced* frames by energy
   (silence removal — unvoiced frames carry no language signal).
2. Slice voiced runs into segments; keep the longest ones (bounded CPU).
3. Embed each segment with pre-trained SpeechBrain ECAPA
   (``lang-id-voxlingua107-ecapa`` — 107 spoken languages, incl.
   Sanskrit/Tamil/Telugu/Hindi/Marathi/Nepali/Urdu/Sinhala).
4. Duration-weighted average of segment posteriors -> song posterior.

No classifier is trained: the posterior top-1 is accepted only above a
per-call confidence threshold, otherwise the track abstains (``None``),
per the missing-modality robustness principle (paper §4.3.3).

Heavy deps (torch/speechbrain) are lazy: import-time never fails, and
every public function degrades to ``None``/``{}`` without them.
"""

import logging
import os

logger = logging.getLogger("VocalLang")

ANALYZER_VERSION = "voxlingua-ecapa-v1"
MODEL_SOURCE = "speechbrain/lang-id-voxlingua107-ecapa"

# VoxLingua107 ISO-639 codes -> our canonical language names.
# Verified against the model's label_encoder.txt (109 classes incl.
# index bookkeeping). Codes with no canonical mapping resolve to None.
VOX_TO_CANONICAL = {
    "sa": "Sanskrit", "ta": "Tamil", "te": "Telugu", "hi": "Hindi",
    "mr": "Marathi", "ne": "Nepali", "ur": "Urdu", "si": "Sinhala",
    "bn": "Bengali", "gu": "Gujarati", "kn": "Kannada", "ml": "Malayalam",
    "pa": "Punjabi", "as": "Assamese", "ar": "Arabic", "fa": "Persian",
    "ja": "Japanese", "ko": "Korean", "zh": "Chinese", "th": "Thai",
    "fr": "French", "de": "German", "es": "Spanish", "pt": "Portuguese",
    "it": "Italian", "ru": "Russian", "el": "Greek", "iw": "Hebrew",
    "ms": "Malay", "id": "Indonesian", "tr": "Turkish", "vi": "Vietnamese",
    "en": "English", "hy": "Armenian", "ka": "Georgian",
}

SILENCE_DB = -40.0
MIN_SEGMENT_SECONDS = 1.0
MERGE_GAP_SECONDS = 0.3
MAX_SEGMENTS = 8
MAX_VOICED_SECONDS = 60.0
MIN_VOICED_SECONDS = 3.0
MODEL_SR = 16000

_classifier = None


def dependencies_available() -> bool:
    try:
        import torch  # noqa: F401
        import speechbrain  # noqa: F401
        import librosa  # noqa: F401
        return True
    except ImportError:
        return False


def canonical_for_vox(code: str | None) -> str | None:
    """Map a VoxLingua ISO code to our canonical language (or None)."""
    if not code:
        return None
    return VOX_TO_CANONICAL.get(str(code).lower())


OVERRIDE_CONFIDENCE = 0.8


def resolve_language(current: str | None, current_source: str | None,
                     vocal_lang: str | None, vocal_conf: float,
                     threshold: float = 0.2) -> tuple:
    """Fuse a vocal-embedding vote with the stored label (Step 4).

    Returns ``(language, source)`` to write, or ``(None, None)`` for no
    change. Rules: manual labels are sacred; unlabeled tracks accept any
    above-threshold vote; auto labels yield only to high-confidence
    disagreement (>= 0.8).
    """
    if not vocal_lang or vocal_conf < threshold:
        return None, None
    if (current_source or "auto") == "manual":
        return None, None
    if not current:
        return vocal_lang, "auto:audio"
    if current != vocal_lang and vocal_conf >= OVERRIDE_CONFIDENCE:
        return vocal_lang, "auto:audio"
    return None, None


def vocal_segments(energy_db, frame_times, db_threshold: float = SILENCE_DB,
                   min_seconds: float = MIN_SEGMENT_SECONDS,
                   merge_gap: float = MERGE_GAP_SECONDS) -> list:
    """Voiced ``[(start, end)]`` runs from per-frame dB energies.

    Pure-numpy logic (lists accepted); unit tested without audio I/O.
    """
    try:
        voiced = [float(e) >= db_threshold for e in energy_db]
    except TypeError:
        return []
    times = list(frame_times)
    segments, start = [], None
    for i, v in enumerate(voiced):
        t = times[i] if i < len(times) else float(i)
        if v and start is None:
            start = t
        elif not v and start is not None:
            if t - start >= min_seconds:
                segments.append([start, t])
            start = None
    if start is not None:
        end = times[-1] if times else start
        if end - start >= min_seconds:
            segments.append([start, end])
    # Merge runs split by a short breather.
    merged = []
    for s, e in segments:
        if merged and s - merged[-1][1] <= merge_gap:
            merged[-1][1] = e
        else:
            merged.append([s, e])
    return [(float(s), float(e)) for s, e in merged]


def weighted_posterior(segment_probs: list) -> dict:
    """Duration-weighted average of ``(prob_dict, seconds)`` segments."""
    totals, weights = {}, 0.0
    for probs, seconds in segment_probs:
        if seconds <= 0:
            continue
        weights += seconds
        for lang, p in (probs or {}).items():
            totals[lang] = totals.get(lang, 0.0) + float(p) * seconds
    if weights <= 0:
        return {}
    return {lang: v / weights for lang, v in totals.items()}


def top_language(posterior: dict, threshold: float = 0.0):
    """(language, confidence) top-1 above ``threshold`` else (None, best)."""
    if not posterior:
        return None, 0.0
    best = max(posterior.items(), key=lambda kv: kv[1])
    if best[1] >= threshold:
        return best[0], float(best[1])
    return None, float(best[1])


def _get_classifier():
    global _classifier
    if _classifier is not None:
        return _classifier
    from speechbrain.inference.classifiers import EncoderClassifier

    _classifier = EncoderClassifier.from_hparams(source=MODEL_SOURCE)
    return _classifier


def analyze_vocal_language(path: str, threshold: float = 0.2) -> dict | None:
    """Full pipeline for one audio file. Never raises; None on abstain.

    Default threshold 0.2: singing posteriors over 107 classes are
    diffuse (top mass ~0.2-0.4 even when correct — cf. the paper's
    VoxLingua baseline), so the bar favors recall with abstention below
    it. Tune per language as labeled data accumulates.
    """
    if not dependencies_available():
        return None
    if not path or not os.path.exists(path):
        return None
    try:
        import librosa
        import numpy as np

        from app.services.audio_analysis import _decode_prefix_to_wav, ANALYZE_SECONDS

        wav = _decode_prefix_to_wav(path, seconds=ANALYZE_SECONDS)
        if not wav:
            return None
        try:
            y, sr = librosa.load(wav, sr=MODEL_SR, mono=True)
        finally:
            try:
                os.remove(wav)
            except OSError:
                pass
        if y is None or len(y) < MODEL_SR:
            return None

        # Frame energies in dB relative to the track peak (silence removal).
        hop = 512
        frames = librosa.util.frame(y, frame_length=2048, hop_length=hop).astype(float)
        rms = np.sqrt(np.mean(frames ** 2, axis=0) + 1e-12)
        peak = float(np.max(rms)) + 1e-12
        energy_db = 20.0 * np.log10(rms / peak + 1e-12)
        times = librosa.frames_to_time(np.arange(len(rms)), sr=MODEL_SR, hop_length=hop)
        segments = vocal_segments(
            [float(e) for e in energy_db], [float(t) for t in times]
        )
        # Longest segments first, bounded total voiced audio.
        segments = sorted(segments, key=lambda se: se[1] - se[0], reverse=True)
        picked, budget = [], MAX_VOICED_SECONDS
        for s, e in segments:
            if len(picked) >= MAX_SEGMENTS or budget <= 0:
                break
            dur = min(e - s, budget)
            picked.append((s, s + dur))
            budget -= dur
        voiced_total = sum(e - s for s, e in picked)
        if voiced_total < MIN_VOICED_SECONDS:
            return None

        clf = _get_classifier()
        import torch

        lab_enc = clf.hparams.label_encoder
        seg_probs = []
        for s, e in picked:
            chunk = y[int(s * MODEL_SR):int(e * MODEL_SR)]
            if len(chunk) < MODEL_SR // 2:
                continue
            wav_t = torch.from_numpy(chunk).unsqueeze(0)
            with torch.no_grad():
                # (log-posteriors [B, 107], best score, best index, labels)
                log_probs, _score, _idx, _text_lab = clf.classify_batch(wav_t)
            probs = log_probs[0].detach().cpu().exp()
            topk = torch.topk(probs, k=min(5, len(probs)))
            dist = {}
            for score, lab_i in zip(topk.values.tolist(), topk.indices.tolist()):
                code = lab_enc.ind2lab.get(int(lab_i), "")
                # Codes look like "sa: Sanskrit" — take the ISO part.
                code = str(code).split(":")[0].strip().strip("'\"")
                canon = canonical_for_vox(code)
                # Keep unmapped codes as other:<iso> so the margin math
                # sees the full distribution, not just canonical hits.
                label = canon if canon else f"other:{code or '?'}"
                dist[label] = dist.get(label, 0.0) + float(score)
            seg_probs.append((dist, e - s))
        posterior = weighted_posterior(seg_probs)
        if not posterior:
            return None
        lang, conf = top_language(posterior, threshold=0.0)
        if lang and lang.startswith("other:"):
            lang = None  # top mass on an unmapped language: abstain
        ordered = sorted(posterior.items(), key=lambda kv: -kv[1])
        margin = round(float(ordered[0][1] - (ordered[1][1] if len(ordered) > 1 else 0.0)), 4)
        top5 = [[k, round(float(v), 4)] for k, v in ordered[:5]]
        accepted = bool(lang and conf >= threshold)
        return {
            "language": lang if accepted else None,
            "confidence": round(float(conf), 3),
            "margin": margin,
            "accepted": accepted,
            "threshold": threshold,
            "posteriors_top5": top5,
            "voiced_seconds": round(float(voiced_total), 1),
            "segments_used": len(seg_probs),
            "analyzer": ANALYZER_VERSION,
        }
    except Exception as e:
        logger.warning(f"vocal language analysis failed for {path}: {e}")
        return None
