import React, { useState, useEffect, useRef } from 'react';
import Fuse from 'fuse.js';
import { searchLibrary } from './api';

const SmartSearch = ({ songs, onSelectSong, onSelectAlbum, onSelectArtist, onSearchSubmit }) => {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [albums, setAlbums] = useState([]);
    const [artists, setArtists] = useState([]);
    const [isOpen, setIsOpen] = useState(false);
    const searchRef = useRef(null);
    const fuseRef = useRef(null);
    const debounceRef = useRef(null);

    // Initialize Fuse
    useEffect(() => {
        if (songs.length > 0) {
            fuseRef.current = new Fuse(songs, {
                keys: ['title', 'artist', 'album'],
                threshold: 0.3, // Fuzzy threshold
                ignoreLocation: true
            });
        }
    }, [songs]);

    // Handle Search (songs locally, albums/artists via server)
    useEffect(() => {
        if (query.trim() && fuseRef.current) {
            const res = fuseRef.current.search(query);
            setResults(res.slice(0, 5).map(r => r.item)); // Limit to 5 (room for albums/artists)
        } else {
            setResults([]);
        }

        if (debounceRef.current) clearTimeout(debounceRef.current);
        if (query.trim().length >= 2) {
            debounceRef.current = setTimeout(async () => {
                try {
                    const data = await searchLibrary(query.trim());
                    setAlbums((data.albums || []).slice(0, 3));
                    setArtists((data.artists || []).slice(0, 3));
                } catch (err) {
                    console.error('Search failed:', err);
                }
            }, 300);
        } else {
            setAlbums([]);
            setArtists([]);
        }
        return () => {
            if (debounceRef.current) clearTimeout(debounceRef.current);
        };
    }, [query]);

    // Click outside to close
    useEffect(() => {
        const handleClickOutside = (event) => {
            if (searchRef.current && !searchRef.current.contains(event.target)) {
                setIsOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const handleSelect = (song) => {
        onSelectSong(song);
        setIsOpen(false);
        setQuery('');
    };

    const handleSelectAlbum = (album) => {
        onSelectAlbum?.(album);
        setIsOpen(false);
        setQuery('');
    };

    const handleSelectArtist = (artist) => {
        onSelectArtist?.(artist);
        setIsOpen(false);
        setQuery('');
    };

    const handleKeyDown = (e) => {
        if (e.key === 'Enter' && query.trim()) {
            e.preventDefault();
            onSearchSubmit?.(query.trim());
            setIsOpen(false);
        }
    };

    const triggerFullSearch = () => {
        if (query.trim()) {
            onSearchSubmit?.(query.trim());
            setIsOpen(false);
        }
    };

    const hasAny = results.length > 0 || albums.length > 0 || artists.length > 0;

    return (
        <div className="relative" ref={searchRef}>
            <div className={`flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 hover:bg-white/10 transition-all border border-transparent focus-within:border-pink-500/50 focus-within:bg-white/10 ${isOpen ? 'w-64' : 'w-48'}`}>
                <svg className="w-4 h-4 text-white/50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <input
                    type="text"
                    value={query}
                    onChange={(e) => {
                        setQuery(e.target.value);
                        setIsOpen(true);
                    }}
                    onFocus={() => setIsOpen(true)}
                    onKeyDown={handleKeyDown}
                    placeholder="Search music (Press Enter)..."
                    className="bg-transparent border-none focus:outline-none text-sm text-white placeholder-white/50 w-full"
                />
            </div>

            {/* Dropdown Results */}
            {isOpen && query && hasAny && (
                <div className="absolute top-full mt-2 w-80 right-0 bg-[#0f111a]/95 backdrop-blur-xl border border-white/10 rounded-xl shadow-2xl overflow-hidden z-[100] animate-scale-in origin-top-right max-h-[70vh] overflow-y-auto">
                    <div className="p-2">
                        {/* Quick View All Banner */}
                        <div
                            onClick={triggerFullSearch}
                            className="p-2.5 bg-gradient-to-r from-pink-500/20 to-purple-500/20 hover:from-pink-500/30 hover:to-purple-500/30 text-white font-medium text-xs rounded-lg text-center cursor-pointer transition border border-pink-500/30 mb-2 flex items-center justify-between"
                        >
                            <span className="truncate">See all results for "{query.trim()}"</span>
                            <svg className="w-4 h-4 text-pink-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
                            </svg>
                        </div>

                        {artists.length > 0 && (
                            <>
                                <p className="text-[11px] font-bold text-white/40 uppercase tracking-wider px-2 pt-1 pb-1">Artists</p>
                                {artists.map((artist) => (
                                    <div
                                        key={artist.key}
                                        onClick={() => handleSelectArtist(artist)}
                                        className="flex items-center gap-3 p-2 rounded-lg hover:bg-white/10 cursor-pointer transition"
                                    >
                                        {artist.cover_art ? (
                                            <img src={artist.cover_art} className="w-10 h-10 rounded-full bg-white/5 object-cover" alt="" />
                                        ) : (
                                            <div className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center">
                                                <svg className="w-5 h-5 text-white/30" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" /></svg>
                                            </div>
                                        )}
                                        <div className="min-w-0">
                                            <h4 className="text-sm font-medium text-white truncate">{artist.name}</h4>
                                            <p className="text-xs text-white/50 truncate">{artist.song_count} songs</p>
                                        </div>
                                    </div>
                                ))}
                            </>
                        )}
                        {albums.length > 0 && (
                            <>
                                <p className="text-[11px] font-bold text-white/40 uppercase tracking-wider px-2 pt-1 pb-1">Albums</p>
                                {albums.map((album) => (
                                    <div
                                        key={album.id}
                                        onClick={() => handleSelectAlbum(album)}
                                        className="flex items-center gap-3 p-2 rounded-lg hover:bg-white/10 cursor-pointer transition"
                                    >
                                        {album.cover_art ? (
                                            <img src={album.cover_art} className="w-10 h-10 rounded bg-white/5 object-cover" alt="" />
                                        ) : (
                                            <div className="w-10 h-10 rounded bg-white/5 flex items-center justify-center">
                                                <svg className="w-5 h-5 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                                            </div>
                                        )}
                                        <div className="min-w-0">
                                            <h4 className="text-sm font-medium text-white truncate">{album.name}</h4>
                                            <p className="text-xs text-white/50 truncate">{album.song_count} songs</p>
                                        </div>
                                    </div>
                                ))}
                            </>
                        )}
                        {results.length > 0 && (
                            <>
                                <p className="text-[11px] font-bold text-white/40 uppercase tracking-wider px-2 pt-1 pb-1">Songs</p>
                                {results.map((song) => (
                                    <div
                                        key={song.id}
                                        onClick={() => handleSelect(song)}
                                        className="flex items-center gap-3 p-2 rounded-lg hover:bg-white/10 cursor-pointer transition"
                                    >
                                        <img
                                            src={song.cover_art || song.thumbnail || 'https://via.placeholder.com/40'}
                                            className="w-10 h-10 rounded bg-white/5 object-cover"
                                            onError={(e) => e.target.src = 'https://via.placeholder.com/40'}
                                        />
                                        <div className="min-w-0">
                                            <h4 className="text-sm font-medium text-white truncate">{song.title}</h4>
                                            <p className="text-xs text-white/50 truncate">{song.artist}</p>
                                        </div>
                                    </div>
                                ))}
                            </>
                        )}
                    </div>
                </div>
            )}

            {/* No Results */}
            {isOpen && query && !hasAny && (
                <div className="absolute top-full mt-2 w-64 right-0 bg-[#0f111a]/95 backdrop-blur-xl border border-white/10 rounded-xl shadow-2xl p-4 text-center z-[100]">
                    <p className="text-sm text-white/50 mb-2">No quick results found</p>
                    <button
                        onClick={triggerFullSearch}
                        className="px-3 py-1.5 bg-pink-500/20 text-pink-300 rounded-lg text-xs font-medium hover:bg-pink-500/30 transition"
                    >
                        Search library for "{query}"
                    </button>
                </div>
            )}
        </div>
    );
};

export default SmartSearch;
