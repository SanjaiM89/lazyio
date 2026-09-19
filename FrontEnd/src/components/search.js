import Fuse from 'fuse.js';

// Typo-tolerant client-side index over the already-loaded library.
// Used as instant dropdown results AND as a fallback merged under
// server results (covers the case where only the first page of songs
// is loaded locally but the server is unreachable/slow).
const SONG_KEYS = [
  { name: 'title', weight: 0.6 },
  { name: 'artist', weight: 0.3 },
  { name: 'album', weight: 0.1 },
];

export function makeSongIndex(songs) {
  return new Fuse(songs || [], {
    keys: SONG_KEYS,
    threshold: 0.4, // typo-tolerant, still strict enough to avoid junk
    ignoreLocation: true,
    includeScore: true,
    minMatchCharLength: 2,
  });
}

export function fuzzySongs(index, query, limit = 6) {
  const q = (query || '').trim();
  if (!q || q.length < 2 || !index) return [];
  return index.search(q).slice(0, limit).map((r) => r.item);
}

// Merge server hits with local fuzzy hits, de-duplicated by id.
export function mergeSongs(serverSongs, localSongs) {
  const seen = new Set();
  const out = [];
  for (const s of [...(serverSongs || []), ...(localSongs || [])]) {
    const id = s?.id ?? s?._id;
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(s);
  }
  return out;
}
