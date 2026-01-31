import React, { useState } from 'react';
import { refreshHomepage, recordPlay, deleteSong } from './api';
import SongMenu from './SongMenu';

const Home = ({ data, onPlaySong, onNavigate, onRefresh, onOpenPlaylistModal }) => {
    const [refreshing, setRefreshing] = useState(false);

    // Use passed data or show loading/empty state if waiting
    const loading = !data;

    const handleRefresh = async () => {
        setRefreshing(true);
        try {
            await refreshHomepage();
            // Trigger parent refresh after delay for backend processing
            setTimeout(() => {
                onRefresh?.();
                setRefreshing(false);
            }, 3000);
        } catch (err) {
            console.error('Refresh failed:', err);
            setRefreshing(false);
        }
    };

    const handlePlay = (song) => {
        // Optimize: Play immediately without waiting for recordPlay
        onPlaySong?.(song);

        // Record in background
        recordPlay(song.id).catch(err => {
            console.error('Failed to record play:', err);
        });
    };

    const formatDuration = (seconds) => {
        if (!seconds) return '--:--';
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    if (loading) {
        return (
            <div className="flex-1 flex items-center justify-center">
                <div className="w-12 h-12 rounded-full border-2 border-pink-500/30 border-t-pink-500 animate-spin" />
            </div>
        );
    }

    return (
        <div className="flex-1 overflow-y-auto p-8">
            <div className="max-w-6xl mx-auto">
                {/* Header */}
                <div className="flex justify-between items-center mb-8">
                    <div>
                        <h1 className="text-3xl font-bold mb-2 animate-fade-in">Welcome Back</h1>
                        <p className="text-white/50 animate-fade-in" style={{ animationDelay: '0.1s' }}>Your personalized music experience</p>
                    </div>
                    <button
                        onClick={handleRefresh}
                        disabled={refreshing}
                        className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 transition disabled:opacity-50"
                    >
                        <svg className={`w-5 h-5 ${refreshing ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                        {refreshing ? 'Refreshing...' : 'Refresh'}
                    </button>
                </div>

                {/* Recently Played */}
                {data.recently_played?.length > 0 && (
                    <section className="mb-10 animate-fade-in" style={{ animationDelay: '0.2s' }}>
                        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                            <span className="text-pink-500">⏱</span> Recently Played
                        </h2>
                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                            {data.recently_played.slice(0, 5).map((song) => (
                                <div
                                    key={song.id}
                                    onClick={() => handlePlay(song)}
                                    className="glass rounded-xl p-3 cursor-pointer hover:bg-white/10 hover:-translate-y-1 hover:shadow-xl hover:shadow-pink-500/10 hover:border-pink-500/30 transition duration-300 group"
                                >
                                    <div className="aspect-square rounded-lg bg-gradient-to-br from-pink-500/20 to-purple-600/20 mb-3 flex items-center justify-center overflow-hidden shadow-lg">
                                        {song.cover_art ? (
                                            <img src={song.cover_art} alt="" className="w-full h-full object-cover transform group-hover:scale-110 transition duration-500" />
                                        ) : (
                                            <svg className="w-10 h-10 text-white/20 group-hover:text-pink-500/50 transition" fill="currentColor" viewBox="0 0 24 24">
                                                <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                                            </svg>
                                        )}
                                    </div>
                                    <p className="font-medium text-sm truncate">{song.title}</p>
                                    <p className="text-white/50 text-xs truncate">{song.artist}</p>
                                </div>
                            ))}
                        </div>
                    </section>
                )}

                {/* AI Playlist */}
                {data.ai_playlist?.songs?.length > 0 && (
                    <section className="mb-10 animate-fade-in" style={{ animationDelay: '0.3s' }}>
                        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                            <span className="text-purple-500">✨</span> {data.ai_playlist.name}
                            <span className="text-xs bg-gradient-to-r from-pink-500 to-purple-500 px-2 py-0.5 rounded-full">AI Generated</span>
                        </h2>
                        <div className="glass rounded-2xl overflow-hidden">
                            {data.ai_playlist.songs.map((song, idx) => (
                                <div
                                    key={song.id}
                                    onClick={() => handlePlay(song)}
                                    className="flex items-center gap-4 p-4 hover:bg-white/5 cursor-pointer transition border-b border-white/5 last:border-0"
                                >
                                    <span className="text-white/30 w-6 text-center">{idx + 1}</span>
                                    <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-purple-500/20 to-pink-600/20 flex items-center justify-center overflow-hidden flex-shrink-0">
                                        {song.cover_art ? (
                                            <img src={song.cover_art} alt="" className="w-full h-full object-cover" />
                                        ) : (
                                            <svg className="w-6 h-6 text-white/20" fill="currentColor" viewBox="0 0 24 24">
                                                <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                                            </svg>
                                        )}
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <p className="font-medium truncate">{song.title}</p>
                                        <p className="text-white/50 text-sm truncate">{song.artist}</p>
                                    </div>
                                    <SongMenu
                                        className="opacity-0 group-hover:opacity-100 transition"
                                        song={song}
                                        onAddToPlaylist={onOpenPlaylistModal}
                                        onDelete={async (s) => {
                                            try {
                                                await deleteSong(s.id);
                                                onRefresh(); // Refresh list using prop
                                            } catch (err) {
                                                console.error("Failed to delete song:", err);
                                            }
                                        }}
                                    />
                                    <span className="text-white/30 text-sm">{formatDuration(song.duration)}</span>
                                </div>
                            ))}
                        </div>
                    </section>
                )}

                {/* Last Updated */}
                {data.last_updated && (
                    <p className="text-center text-white/20 text-xs mt-10">
                        AI recommendations last updated: {new Date(data.last_updated).toLocaleString()}
                    </p>
                )}
            </div>
        </div>
    );
};

export default Home;
