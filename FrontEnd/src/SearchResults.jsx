import React, { useState, useEffect } from 'react';
import { searchLibrary, recordPlay } from './api';
import SongMenu from './SongMenu';
import AlbumMenu from './AlbumMenu';

const SearchResults = ({
    query,
    onPlaySong,
    onSelectAlbum,
    onSelectArtist,
    onOpenPlaylistModal,
    onAddAlbumToPlaylist
}) => {
    const [results, setResults] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!query || !query.trim()) {
            setResults(null);
            setLoading(false);
            return;
        }

        const fetchResults = async () => {
            setLoading(true);
            try {
                const data = await searchLibrary(query.trim(), 50, 50, 50);
                setResults(data);
            } catch (err) {
                console.error('Failed to load search results:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchResults();
    }, [query]);

    const formatDuration = (seconds) => {
        if (!seconds) return '--:--';
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    if (loading) {
        return (
            <div className="flex-1 flex items-center justify-center p-8">
                <div className="w-12 h-12 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
            </div>
        );
    }

    const songs = results?.songs || [];
    const albums = results?.albums || [];
    const artists = results?.artists || [];
    const totalCount = songs.length + albums.length + artists.length;

    if (totalCount === 0) {
        return (
            <div className="flex-1 flex flex-col items-center justify-center p-8 text-center">
                <div className="w-20 h-20 rounded-full bg-white/5 flex items-center justify-center mb-4">
                    <svg className="w-10 h-10 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                </div>
                <h2 className="text-2xl font-bold mb-2">No results found</h2>
                <p className="text-white/50 text-sm max-w-md">
                    We couldn't find any songs, albums, or artists matching <span className="text-pink-400">"{query}"</span>. Try checking spelling or search for something else.
                </p>
            </div>
        );
    }

    return (
        <div className="flex-1 overflow-y-auto p-8">
            <div className="max-w-6xl mx-auto space-y-10">
                {/* Header */}
                <div>
                    <h1 className="text-3xl font-bold mb-2">
                        Search Results for <span className="bg-gradient-to-r from-pink-500 to-purple-500 bg-clip-text text-transparent">"{query}"</span>
                    </h1>
                    <p className="text-white/50 text-sm">
                        Found {songs.length} song{songs.length !== 1 ? 's' : ''}, {albums.length} album{albums.length !== 1 ? 's' : ''}, and {artists.length} artist{artists.length !== 1 ? 's' : ''}
                    </p>
                </div>

                {/* Artists Section */}
                {artists.length > 0 && (
                    <section>
                        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                            <span>🎙️</span> Artists ({artists.length})
                        </h2>
                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                            {artists.map((artist) => (
                                <div
                                    key={artist.key}
                                    onClick={() => onSelectArtist?.(artist)}
                                    className="glass rounded-xl p-4 cursor-pointer hover:bg-white/10 hover:scale-[1.02] transition duration-300 group text-center"
                                >
                                    <div className="w-24 h-24 rounded-full bg-gray-800 mb-3 flex items-center justify-center overflow-hidden mx-auto shadow-lg">
                                        {artist.cover_art ? (
                                            <img src={artist.cover_art} alt="" className="w-full h-full object-cover transform group-hover:scale-110 transition duration-500" />
                                        ) : (
                                            <svg className="w-12 h-12 text-white/20" fill="currentColor" viewBox="0 0 24 24">
                                                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
                                            </svg>
                                        )}
                                    </div>
                                    <p className="font-bold text-sm truncate text-white">{artist.name}</p>
                                    <p className="text-white/50 text-xs truncate mt-0.5">{artist.song_count || 0} songs</p>
                                </div>
                            ))}
                        </div>
                    </section>
                )}

                {/* Albums Section */}
                {albums.length > 0 && (
                    <section>
                        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                            <span>💿</span> Albums ({albums.length})
                        </h2>
                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                            {albums.map((album) => (
                                <div
                                    key={album.id}
                                    onClick={() => onSelectAlbum?.(album)}
                                    className="glass rounded-xl p-3 cursor-pointer hover:bg-white/10 hover:scale-[1.02] transition duration-300 group"
                                >
                                    <div className="aspect-square rounded-lg bg-gray-800 mb-3 flex items-center justify-center relative overflow-hidden shadow-lg">
                                        {album.cover_art ? (
                                            <img src={album.cover_art} alt="" className="w-full h-full object-cover transform group-hover:scale-110 transition duration-500" />
                                        ) : (
                                            <svg className="w-12 h-12 text-white/20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                                            </svg>
                                        )}
                                        {onAddAlbumToPlaylist && (
                                            <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition" onClick={e => e.stopPropagation()}>
                                                <AlbumMenu
                                                    songIds={album.song_ids || []}
                                                    onAddAlbumToPlaylist={onAddAlbumToPlaylist}
                                                    className="[&>button]:bg-black/50"
                                                />
                                            </div>
                                        )}
                                    </div>
                                    <p className="font-bold text-sm truncate text-white">{album.name}</p>
                                    <p className="text-white/50 text-xs truncate mt-0.5">{album.artist || 'Unknown Artist'}</p>
                                </div>
                            ))}
                        </div>
                    </section>
                )}

                {/* Songs Section */}
                {songs.length > 0 && (
                    <section>
                        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                            <span>🎵</span> Songs ({songs.length})
                        </h2>
                        <div className="glass rounded-2xl overflow-hidden">
                            {songs.map((song, idx) => (
                                <div
                                    key={song.id}
                                    onClick={() => onPlaySong?.(song)}
                                    className="flex items-center gap-4 p-4 hover:bg-white/5 cursor-pointer transition border-b border-white/5 last:border-0 group"
                                >
                                    <span className="text-white/30 w-6 text-center text-sm">{idx + 1}</span>
                                    <div className="w-12 h-12 rounded-lg bg-gray-800 flex items-center justify-center overflow-hidden flex-shrink-0 shadow">
                                        {song.cover_art || song.thumbnail ? (
                                            <img src={song.cover_art || song.thumbnail} alt="" className="w-full h-full object-cover" />
                                        ) : (
                                            <svg className="w-6 h-6 text-white/20" fill="currentColor" viewBox="0 0 24 24">
                                                <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                                            </svg>
                                        )}
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <p className="font-medium truncate text-white">{song.title}</p>
                                        <p className="text-white/50 text-sm truncate">{song.artist || 'Unknown Artist'}</p>
                                    </div>
                                    <span className="text-white/40 text-sm hidden md:inline truncate max-w-xs">{song.album || ''}</span>
                                    <SongMenu
                                        className="opacity-0 group-hover:opacity-100 transition"
                                        song={song}
                                        onAddToPlaylist={onOpenPlaylistModal}
                                    />
                                    <span className="text-white/30 text-sm font-mono">{formatDuration(song.duration)}</span>
                                </div>
                            ))}
                        </div>
                    </section>
                )}
            </div>
        </div>
    );
};

export default SearchResults;
