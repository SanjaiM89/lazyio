import React, { useState, useEffect } from 'react';
import { getPlaylists, createPlaylist, deletePlaylist, getPlaylist, removeSongFromPlaylist } from './api';
import SongMenu from './SongMenu';

const Playlists = ({ onPlaySong, onNavigate, onOpenPlaylistModal }) => {
    const [playlists, setPlaylists] = useState([]);
    const [selectedPlaylist, setSelectedPlaylist] = useState(null);
    const [loading, setLoading] = useState(true);
    const [creating, setCreating] = useState(false);
    const [newPlaylistName, setNewPlaylistName] = useState('');

    useEffect(() => {
        loadPlaylists();
    }, []);

    const loadPlaylists = async () => {
        setLoading(true);
        try {
            const data = await getPlaylists(1, 100);
            setPlaylists(data.items || []);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const handleCreate = async () => {
        if (!newPlaylistName.trim()) return;
        setCreating(true);
        try {
            const added = await createPlaylist(newPlaylistName);
            setPlaylists([...playlists, added]);
            setNewPlaylistName('');
        } catch (err) {
            console.error(err);
        } finally {
            setCreating(false);
        }
    };

    const handleDelete = async (e, id) => {
        e.stopPropagation();
        if (!confirm("Delete this playlist?")) return;
        try {
            await deletePlaylist(id);
            setPlaylists(playlists.filter(p => p.id !== id));
            if (selectedPlaylist?.id === id) setSelectedPlaylist(null);
        } catch (err) {
            console.error(err);
        }
    };

    const handleSelectPlaylist = async (playlist) => {
        setLoading(true);
        try {
            const details = await getPlaylist(playlist.id);
            setSelectedPlaylist(details);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const handleRemoveSong = async (songId) => {
        if (!selectedPlaylist) return;
        try {
            await removeSongFromPlaylist(selectedPlaylist.id, songId);
            // Update local state
            setSelectedPlaylist({
                ...selectedPlaylist,
                songs: selectedPlaylist.songs.filter(s => s.id !== songId)
            });
        } catch (err) {
            console.error(err);
        }
    };

    if (selectedPlaylist) {
        return (
            <div className="h-full flex flex-col p-8 overflow-y-auto">
                <div className="max-w-5xl mx-auto w-full">
                    <button onClick={() => setSelectedPlaylist(null)} className="mb-6 flex items-center gap-2 text-white/50 hover:text-white transition">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
                        Back to Playlists
                    </button>

                    <div className="flex items-end gap-6 mb-8">
                        <div className="w-48 h-48 rounded-xl bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center shadow-2xl">
                            <svg className="w-20 h-20 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                        </div>
                        <div>
                            <p className="text-white/60 uppercase tracking-widest text-xs font-bold mb-1">Playlist</p>
                            <h1 className="text-6xl font-bold mb-4">{selectedPlaylist.name}</h1>
                            <p className="text-white/60">{selectedPlaylist.songs?.length || 0} songs</p>
                        </div>
                    </div>

                    <div className="space-y-1">
                        {selectedPlaylist.songs?.map((song, idx) => (
                            <div key={song.id} className="group flex items-center gap-4 p-3 rounded-lg hover:bg-white/5 transition cursor-pointer" onClick={() => onPlaySong(song)}>
                                <span className="text-white/30 w-8 text-center">{idx + 1}</span>
                                <img src={song.cover_art || song.thumbnail} className="w-10 h-10 rounded object-cover bg-gray-800" alt="" />
                                <div className="flex-1 min-w-0">
                                    <p className="font-medium text-white truncate">{song.title}</p>
                                    <p className="text-sm text-white/50 truncate">{song.artist}</p>
                                </div>

                                {/* Menu for current song */}
                                <div className="opacity-0 group-hover:opacity-100 transition flex items-center gap-2">
                                    <SongMenu song={song} onAddToPlaylist={onOpenPlaylistModal} />
                                    <button
                                        onClick={(e) => { e.stopPropagation(); handleRemoveSong(song.id); }}
                                        className="p-2 text-white/30 hover:text-red-400"
                                        title="Remove from playlist"
                                    >
                                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                                    </button>
                                </div>
                            </div>
                        ))}
                        {(!selectedPlaylist.songs || selectedPlaylist.songs.length === 0) && (
                            <div className="text-center py-20 text-white/30">
                                This playlist is empty. Go to Library to add songs!
                            </div>
                        )}
                    </div>
                </div>
            </div>
        );
    }

    // List Playlists
    return (
        <div className="h-full flex flex-col p-8 overflow-y-auto">
            <div className="max-w-6xl mx-auto w-full">
                <h1 className="text-3xl font-bold mb-8">Playlists</h1>

                {/* Create New */}
                <div className="bg-white/5 rounded-xl p-6 mb-8 flex items-center gap-4">
                    <div className="w-12 h-12 rounded-lg bg-pink-500/20 flex items-center justify-center">
                        <svg className="w-6 h-6 text-pink-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" /></svg>
                    </div>
                    <div className="flex-1">
                        <input
                            type="text"
                            placeholder="Create new playlist..."
                            className="w-full bg-transparent border-none focus:outline-none text-lg placeholder-white/30"
                            value={newPlaylistName}
                            onChange={(e) => setNewPlaylistName(e.target.value)}
                            onKeyDown={(e) => e.key === 'Enter' && handleCreate()}
                        />
                    </div>
                    <button
                        onClick={handleCreate}
                        disabled={!newPlaylistName.trim() || creating}
                        className="px-6 py-2 bg-pink-500 hover:bg-pink-600 rounded-lg font-medium transition disabled:opacity-50"
                    >
                        Create
                    </button>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                    {/* Liked Songs Fake Playlist (Optional) */}
                    <div className="aspect-square rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 p-6 flex flex-col justify-end cursor-pointer hover:scale-[1.02] transition shadow-lg opacity-80 hover:opacity-100" onClick={() => alert("Liked songs feature coming soon!")}>
                        <h3 className="text-2xl font-bold">Liked Songs</h3>
                        <p className="text-white/60">0 songs</p>
                    </div>

                    {playlists.map(pl => (
                        <div key={pl.id} onClick={() => handleSelectPlaylist(pl)} className="group glass rounded-xl p-4 cursor-pointer hover:bg-white/10 hover:scale-[1.02] hover:shadow-2xl hover:shadow-pink-500/10 hover:border-pink-500/30 transition duration-300 flex flex-col relative overflow-hidden">
                            <div className="absolute inset-0 bg-gradient-to-br from-pink-500/5 to-purple-600/5 opacity-0 group-hover:opacity-100 transition duration-500" />
                            <div className="aspect-square rounded-lg bg-gray-800 mb-4 flex items-center justify-center relative overflow-hidden shadow-lg group-hover:shadow-pink-500/20 transition">
                                {pl.cover_art ? (
                                    <img src={pl.cover_art} className="w-full h-full object-cover transform group-hover:scale-110 transition duration-500" alt="" />
                                ) : (
                                    <svg className="w-16 h-16 text-white/10 group-hover:text-pink-500/50 transition duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                                )}
                                {/* Delete Btn */}
                                <button
                                    onClick={(e) => handleDelete(e, pl.id)}
                                    className="absolute top-2 right-2 p-2 rounded-full bg-black/50 text-white/50 hover:text-red-500 hover:bg-black/80 opacity-0 group-hover:opacity-100 transition"
                                >
                                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                                </button>
                            </div>
                            <h3 className="font-bold truncate">{pl.name}</h3>
                            <p className="text-sm text-white/50">{pl.song_count || 0} songs</p>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

export default Playlists;
