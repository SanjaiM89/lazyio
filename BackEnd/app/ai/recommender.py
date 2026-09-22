"""Content-based similarity for Lazyio (Phase 1).

Vectors are 19-dim librosa descriptors (see app.services.audio_analysis):
``[bpm/200, danceability, energy, instrumentalness, lofi, valence]`` plus
13 mean MFCCs. Indexed in-process with FAISS; persisted per song in Mongo
(``audio_vector``) and reloaded at startup (see ``app/main.py``).

All heavy dependencies are optional: without numpy/librosa/faiss the
module loads fine and every lookup degrades to ``[]``.
"""

import asyncio
import logging
import os
from typing import List

logger = logging.getLogger("AudioRecommender")

try:
    import numpy as np
    import faiss
    from app.services.audio_analysis import (
        analyze_file,
        features_to_vector,
        VECTOR_DIM,
        ANALYZER_VERSION,
    )

    DEPENDENCIES_AVAILABLE = True
except ImportError as e:
    logger.warning(f"Audio Recommendation dependencies missing: {e}. Feature disabled.")
    DEPENDENCIES_AVAILABLE = False
    VECTOR_DIM = 19
    ANALYZER_VERSION = "librosa-v1"


class AudioRecommender:
    def __init__(self):
        self.index = None
        self.map_id_to_vector = {}  # song_id -> vector (in-memory lookups)
        self.map_index_to_song_id = {}  # faiss row -> song ID
        self.dimension = 0
        if not DEPENDENCIES_AVAILABLE:
            logger.warning("AudioRecommender initialized but dependencies are missing.")

    def _extract_features(self, file_path: str):
        """19-dim vector for an audio file, or None."""
        if not DEPENDENCIES_AVAILABLE:
            return None
        try:
            features = analyze_file(file_path)
            if not features:
                return None
            vec = features_to_vector(features)
            return np.array(vec, dtype="float32")
        except Exception as e:
            print(f"[AudioRecommender] Extraction error for {file_path}: {e}")
            return None

    def initialize_index(self, dimension: int):
        """Initialize a new FAISS index"""
        if not DEPENDENCIES_AVAILABLE:
            return

        self.dimension = dimension
        self.index = faiss.IndexFlatL2(dimension)  # L2 distance (Euclidean)
        self.map_index_to_song_id = {}

    def add_to_index(self, song_id: str, vector: List[float]):
        """Add a song vector to the index"""
        if not DEPENDENCIES_AVAILABLE or not vector:
            return

        np_vector = np.array([vector], dtype="float32")

        if self.index is None:
            self.initialize_index(np_vector.shape[1])

        # Guard against dimension drift (e.g. legacy 16-dim rows).
        if np_vector.shape[1] != self.dimension:
            logger.warning(
                f"Skipping vector for {song_id}: dim {np_vector.shape[1]} "
                f"!= index dim {self.dimension}"
            )
            return

        # Add to FAISS
        self.index.add(np_vector)

        # Track mapping
        internal_id = self.index.ntotal - 1
        self.map_index_to_song_id[internal_id] = song_id
        self.map_id_to_vector[song_id] = vector

    def find_similar(self, song_id: str, limit: int = 5) -> List[str]:
        """Find similar songs by ID"""
        if (
            not DEPENDENCIES_AVAILABLE
            or self.index is None
            or song_id not in self.map_id_to_vector
        ):
            return []

        query_vector = np.array([self.map_id_to_vector[song_id]], dtype="float32")

        # Search
        # k = limit + 1 because the query song itself will be found (distance 0)
        distances, indices = self.index.search(query_vector, limit + 1)

        similar_ids = []
        for idx in indices[0]:
            if idx != -1:
                found_id = self.map_index_to_song_id.get(idx)
                if found_id and found_id != song_id:
                    similar_ids.append(found_id)

        return similar_ids[:limit]

    async def process_song(self, song_path: str) -> List[float]:
        """Async wrapper for feature extraction (heavy CPU op)"""
        if not DEPENDENCIES_AVAILABLE or not os.path.exists(song_path):
            return None

        loop = asyncio.get_running_loop()
        # Run in executor to avoid blocking event loop
        vector = await loop.run_in_executor(None, self._extract_features, song_path)

        if vector is not None:
            return vector.tolist()
        return None


# Singleton instance
audio_recommender = AudioRecommender()
