import os
import asyncio
from typing import List, Dict, Tuple
import logging

logger = logging.getLogger("AudioRecommender")

try:
    import numpy as np
    import faiss
    import essentia.standard as es
    DEPENDENCIES_AVAILABLE = True
except ImportError as e:
    logger.warning(f"Audio Recommendation dependencies missing: {e}. Feature disabled.")
    DEPENDENCIES_AVAILABLE = False
    
# Path to store the FAISS index
INDEX_PATH = "audio_features.index"

class AudioRecommender:
    def __init__(self):
        self.index = None
        self.map_id_to_vector = {} # In-memory map for quick lookups
        self.map_index_to_song_id = {} # Map faiss index ID to song ID
        self.dimension = 0
        if not DEPENDENCIES_AVAILABLE:
            logger.warning("AudioRecommender initialized but dependencies are missing.")
        
    def _extract_features(self, file_path: str) -> List[float]:
        if not DEPENDENCIES_AVAILABLE:
            return None
            
        """
        Extracts audio features using Essentia.
        Returns a normalized vector combining:
        - BPM (Tempo)
        - Danceability
        - Energy (RMS)
        - Key/Scale (Tonal)
        """
        try:
            # We use the 'MusicExtractor' for a high-level analysis
            # But for speed, we'll use specific extractors
            
            # Load audio (downsample to 22k for speed, mono)
            loader = es.MonoLoader(filename=file_path, sampleRate=22050)
            audio = loader()
            
            # 1. Rhyhtm / Tempo (using Essentia which is imported as es)
            rhythm_extractor = es.RhythmExtractor2013(method="multifeature")
            bpm, _, _, _, _ = rhythm_extractor(audio)
            
            # 2. Key / Scale
            # key_extractor = es.KeyExtractor()
            # key, scale, strength = key_extractor(audio)
            
            # 3. Energy / Intensity (RMS)
            rms = es.RMS()(audio)
            energy = np.mean(rms)
            
            # 4. Danceability
            danceability, _ = es.Danceability()(audio)
            
            # 5. Spectral Features (Timbre)
            # MFCCs are great for "timbre" similarity
            w = es.Windowing(type = 'hann')
            spectrum = es.Spectrum()
            mfcc = es.MFCC()
            
            mfccs = []
            # Analyze first 30 seconds only for speed/consistency
            limit_samples = min(len(audio), 22050 * 30)
            for frame in es.FrameGenerator(audio[:limit_samples], frameSize=1024, hopSize=512, startFromZero=True):
                mfcc_bands, mfcc_coeffs = mfcc(spectrum(w(frame)))
                mfccs.append(mfcc_coeffs)
            
            avg_mfcc = np.mean(mfccs, axis=0) # vector of 13 floats usually
            
            # Construct final vector
            # Normalize reasonably: BPM/200, Energy*10, Danceability, MFCCs (normalized)
            
            # Simple feature vector: [BPM, Danceability, Energy] + MFCCs
            # We verify the shapes:
            # BPM: scalar
            # Danceability: scalar (0-1 approx)
            # Energy: scalar (0-1 approx)
            # MFCC: 13 dim array
            
            features = np.array([
                bpm / 200.0,       # Normalize BPM roughly 0-1
                danceability,      # Already 0-1
                min(energy * 10, 1.0) # Boost and clip energy
            ], dtype=np.float32)
            
            # Concatenate MFCCs (normalize them too slightly)
            features = np.concatenate((features, avg_mfcc / 100.0))
            
            return features.astype('float32') # Return as numpy array internally
            
        except Exception as e:
            print(f"[AudioRecommender] Extraction error for {file_path}: {e}")
            return None

    def initialize_index(self, dimension: int):
        """Initialize a new FAISS index"""
        if not DEPENDENCIES_AVAILABLE:
            return
            
        self.dimension = dimension
        self.index = faiss.IndexFlatL2(dimension) # L2 distance (Euclidean)
        self.map_index_to_song_id = {}

    def add_to_index(self, song_id: str, vector: List[float]):
        """Add a song vector to the index"""
        if not DEPENDENCIES_AVAILABLE or not vector:
            return
            
        np_vector = np.array([vector], dtype='float32')

        
        if self.index is None:
            self.initialize_index(np_vector.shape[1])
            
        # Add to FAISS
        self.index.add(np_vector)
        
        # Track mapping
        internal_id = self.index.ntotal - 1
        self.map_index_to_song_id[internal_id] = song_id
        self.map_id_to_vector[song_id] = vector

    def find_similar(self, song_id: str, limit: int = 5) -> List[str]:
        """Find similar songs by ID"""
        if not DEPENDENCIES_AVAILABLE or self.index is None or song_id not in self.map_id_to_vector:
            return []
            
        query_vector = np.array([self.map_id_to_vector[song_id]], dtype='float32')
        
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
