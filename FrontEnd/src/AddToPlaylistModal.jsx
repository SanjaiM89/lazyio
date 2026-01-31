import React, { useState, useEffect } from 'react';
import { getPlaylists, createPlaylist, addSongToPlaylist } from './api';

const AddToPlaylistModal = ({ isOpen, onClose, song }) => {
    const [playlists, setPlaylists] = useState([]);
    const [loading, setLoading] = useState(true);
    const [newPlaylistName, setNewPlaylistName] = useState('');
    const [creating, setCreating] = useState(false);
    const [error, setError] = useState(null);

    useEffect(() => {
        if (isOpen) {
            loadPlaylists();
            setError(null);
            setNewPlaylistName('');
        }
    }, [isOpen]);

    const loadPlaylists = async () => {
        setLoading(true);
        try {
            const data = await getPlaylists(1, 100); // Fetch mostly all for this modal
            setPlaylists(data.items || []);
        } catch (err) {
            console.error(err);
            setError('Failed to load playlists');
        } finally {
            setLoading(false);
        }
    };

    const handleCreateAndAdd = async () => {
        if (!newPlaylistName.trim()) return;
        setCreating(true);
        try {
            // Create
            const newPl = await createPlaylist(newPlaylistName);
            // Add song
            if (song) {
                await addSongToPlaylist(newPl.id, song.id);
            }
            onClose();
        } catch (err) {
            setError(err.response?.data?.detail || 'Failed to create playlist');
        } finally {
            setCreating(false);
        }
    };

    const handleAddToExisting = async (playlist) => {
        try {
            await addSongToPlaylist(playlist.id, song.id);
            onClose();
        } catch (err) {
            setError(err.response?.data?.detail || 'Failed to add song');
        }
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-[60] flex items-center justify-center p-4">
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
            <div className="relative bg-[#1a1a2e] border border-white/10 rounded-2xl w-full max-w-md p-6 shadow-2xl">
                <h2 className="text-xl font-bold mb-1">Add to Playlist</h2>
                <p className="text-white/50 text-sm mb-6 truncate">
                    Adding <span className="text-white">{song?.title}</span>
                </p>

                {error && (
                    <div className="bg-red-500/10 border border-red-500/20 text-red-500 text-sm p-3 rounded-lg mb-4">
                        {error}
                    </div>
                )}

                {/* Create New */}
                <div className="flex gap-2 mb-6">
                    <input
                        type="text"
                        placeholder="New playlist name..."
                        className="flex-1 bg-white/5 border border-white/10 rounded-lg px-4 py-2 focus:outline-none focus:border-pink-500/50 transition text-sm"
                        value={newPlaylistName}
                        onChange={(e) => setNewPlaylistName(e.target.value)}
                    />
                    <button
                        onClick={handleCreateAndAdd}
                        disabled={creating || !newPlaylistName.trim()}
                        className="bg-pink-500 hover:bg-pink-600 disabled:opacity-50 disabled:cursor-not-allowed text-white px-4 py-2 rounded-lg text-sm font-medium transition"
                    >
                        {creating ? '...' : 'Create'}
                    </button>
                </div>

                <div className="border-t border-white/5 pt-4">
                    <p className="text-xs font-bold text-white/40 uppercase tracking-wider mb-2">Existing Playlists</p>
                    <div className="max-h-60 overflow-y-auto space-y-1">
                        {loading ? (
                            <div className="text-center py-4 text-white/30 text-sm">Loading...</div>
                        ) : playlists.length === 0 ? (
                            <div className="text-center py-4 text-white/30 text-sm">No playlists found</div>
                        ) : (
                            playlists.map(pl => (
                                <button
                                    key={pl.id}
                                    onClick={() => handleAddToExisting(pl)}
                                    className="w-full text-left p-3 rounded-lg hover:bg-white/5 flex items-center justify-between group transition"
                                >
                                    <div className="flex items-center gap-3">
                                        <div className="w-8 h-8 rounded bg-gradient-to-br from-gray-700 to-gray-800 flex items-center justify-center">
                                            <svg className="w-4 h-4 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                                        </div>
                                        <div>
                                            <p className="font-medium text-sm text-white group-hover:text-pink-400 transition">{pl.name}</p>
                                            <p className="text-xs text-white/40">{pl.song_count || 0} songs</p>
                                        </div>
                                    </div>
                                    <svg className="w-5 h-5 text-white/20 group-hover:text-white transition" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" /></svg>
                                </button>
                            ))
                        )}
                    </div>
                </div>

                <div className="mt-6 flex justify-end">
                    <button onClick={onClose} className="text-white/50 hover:text-white text-sm">Cancel</button>
                </div>
            </div>
        </div>
    );
};

export default AddToPlaylistModal;
