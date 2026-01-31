import React, { useState, useEffect, useRef } from 'react';
import Fuse from 'fuse.js';

const SmartSearch = ({ songs, onSelectSong }) => {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [isOpen, setIsOpen] = useState(false);
    const searchRef = useRef(null);
    const fuseRef = useRef(null);

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

    // Handle Search
    useEffect(() => {
        if (query.trim() && fuseRef.current) {
            const res = fuseRef.current.search(query);
            setResults(res.slice(0, 8).map(r => r.item)); // Limit to 8
        } else {
            setResults([]);
        }
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
                    placeholder="Search music..."
                    className="bg-transparent border-none focus:outline-none text-sm text-white placeholder-white/50 w-full"
                />
            </div>

            {/* Dropdown Results */}
            {isOpen && query && results.length > 0 && (
                <div className="absolute top-full mt-2 w-80 right-0 bg-[#0f111a]/95 backdrop-blur-xl border border-white/10 rounded-xl shadow-2xl overflow-hidden z-[100] animate-scale-in origin-top-right">
                    <div className="p-2">
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
                    </div>
                </div>
            )}

            {/* No Results */}
            {isOpen && query && results.length === 0 && (
                <div className="absolute top-full mt-2 w-64 right-0 bg-[#0f111a]/95 backdrop-blur-xl border border-white/10 rounded-xl shadow-2xl p-4 text-center z-[100]">
                    <p className="text-sm text-white/50">No results found</p>
                </div>
            )}
        </div>
    );
};

export default SmartSearch;
