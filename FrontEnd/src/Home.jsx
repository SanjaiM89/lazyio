import React, { useState, useEffect } from 'react';
import { getHomepage, refreshHomepage, getStreamUrl, recordPlay } from './api';

const Home = ({ onPlaySong, onNavigate }) => {
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);

    const loadData = async () => {
        try {
            const result = await getHomepage();
            setData(result);
        } catch (err) {
            console.error('Failed to load homepage:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadData();

        // WebSocket for live updates
        const ws = new WebSocket('ws://localhost:8000/ws');

        ws.onmessage = (event) => {
            if (event.data === 'library_updated' || event.data === 'song_added') {
                console.log('Home: Library update received, refreshing...');
                loadData();
            }
        };

        return () => {
            ws.close();
        };
    }, []);

    const handleRefresh = async () => {
        setRefreshing(true);
        try {
            await refreshHomepage();
            // Wait a bit for background task to complete
            setTimeout(loadData, 3000);
        } catch (err) {
            console.error('Refresh failed:', err);
        } finally {
            setTimeout(() => setRefreshing(false), 3000);
        }
    };

    const handlePlay = async (song) => {
        try {
            await recordPlay(song.id);
            onPlaySong?.(song);
        } catch (err) {
            console.error('Failed to record play:', err);
            onPlaySong?.(song);
        }
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
                        <h1 className="text-3xl font-bold mb-2">Welcome Back</h1>
                        <p className="text-white/50">Your personalized music experience</p>
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
                {data?.recently_played?.length > 0 && (
                    <section className="mb-10">
                        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                            <span className="text-pink-500">⏱</span> Recently Played
                        </h2>
                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                            {data.recently_played.slice(0, 5).map((song) => (
                                <div
                                    key={song.id}
                                    onClick={() => handlePlay(song)}
                                    className="glass rounded-xl p-3 cursor-pointer hover:bg-white/10 transition group"
                                >
                                    <div className="aspect-square rounded-lg bg-gradient-to-br from-pink-500/20 to-purple-600/20 mb-3 flex items-center justify-center overflow-hidden">
                                        {song.cover_art ? (
                                            <img src={song.cover_art} alt="" className="w-full h-full object-cover" />
                                        ) : (
                                            <svg className="w-10 h-10 text-white/20" fill="currentColor" viewBox="0 0 24 24">
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
                {data?.ai_playlist?.songs?.length > 0 && (
                    <section className="mb-10">
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
                                    <span className="text-white/30 text-sm">{formatDuration(song.duration)}</span>
                                </div>
                            ))}
                        </div>
                    </section>
                )}

                {/* Recommendations */}
                {data?.recommendations?.length > 0 && (
                    <section className="mb-10">
                        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                            <span className="text-green-500">🎵</span> Recommended for You
                        </h2>
                        <div className="glass rounded-2xl p-4">
                            <p className="text-white/50 text-sm mb-3">Based on your library, you might also like:</p>
                            <div className="flex flex-wrap gap-2">
                                {data.recommendations.map((rec, idx) => (
                                    <span
                                        key={idx}
                                        className="px-3 py-1.5 rounded-full bg-white/5 text-sm hover:bg-white/10 cursor-pointer transition"
                                        onClick={() => onNavigate?.('youtube', rec)}
                                    >
                                        {rec}
                                    </span>
                                ))}
                            </div>
                        </div>
                    </section>
                )}

                {/* Quick Actions */}
                <section>
                    <h2 className="text-xl font-semibold mb-4">Quick Actions</h2>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        <button
                            onClick={() => onNavigate?.('youtube')}
                            className="glass rounded-xl p-6 text-left hover:bg-white/10 transition"
                        >
                            <div className="w-12 h-12 rounded-xl bg-red-500/20 flex items-center justify-center mb-3">
                                <svg className="w-6 h-6 text-red-500" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814z" />
                                </svg>
                            </div>
                            <p className="font-medium">YouTube Download</p>
                            <p className="text-white/50 text-sm">Get audio from videos</p>
                        </button>

                        <button
                            onClick={() => onNavigate?.('upload')}
                            className="glass rounded-xl p-6 text-left hover:bg-white/10 transition"
                        >
                            <div className="w-12 h-12 rounded-xl bg-blue-500/20 flex items-center justify-center mb-3">
                                <svg className="w-6 h-6 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                                </svg>
                            </div>
                            <p className="font-medium">Upload Music</p>
                            <p className="text-white/50 text-sm">Add from your device</p>
                        </button>

                        <button
                            onClick={() => onNavigate?.('playlist')}
                            className="glass rounded-xl p-6 text-left hover:bg-white/10 transition"
                        >
                            <div className="w-12 h-12 rounded-xl bg-purple-500/20 flex items-center justify-center mb-3">
                                <svg className="w-6 h-6 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                                </svg>
                            </div>
                            <p className="font-medium">Your Library</p>
                            <p className="text-white/50 text-sm">Browse all songs</p>
                        </button>

                        <button
                            onClick={() => onNavigate?.('playlists')}
                            className="glass rounded-xl p-6 text-left hover:bg-white/10 transition"
                        >
                            <div className="w-12 h-12 rounded-xl bg-green-500/20 flex items-center justify-center mb-3">
                                <svg className="w-6 h-6 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                                </svg>
                            </div>
                            <p className="font-medium">Playlists</p>
                            <p className="text-white/50 text-sm">Create & manage</p>
                        </button>
                    </div>
                </section>

                {/* Last Updated */}
                {data?.last_updated && (
                    <p className="text-center text-white/20 text-xs mt-10">
                        AI recommendations last updated: {new Date(data.last_updated).toLocaleString()}
                    </p>
                )}
            </div>
        </div>
    );
};

export default Home;
