import React, { useState, useEffect, useRef, useCallback } from 'react';
import { getAlbums, getAlbum, scanTelegramChannel } from './api';
import AlbumMenu from './AlbumMenu';

const Albums = ({ onPlaySong, onAddAlbumToPlaylist, focusAlbumId, onClearFocus }) => {
    const [albums, setAlbums] = useState([]);
    const [selected, setSelected] = useState(null);
    const [loading, setLoading] = useState(true);
    const [loadingMore, setLoadingMore] = useState(false);
    const [page, setPage] = useState(1);
    const [pages, setPages] = useState(1);
    const [total, setTotal] = useState(0);
    const [scanning, setScanning] = useState(false);
    const PAGE_SIZE = 60;

    // Refs mirror paging state for the infinite-scroll observer (avoids
    // stale closures without re-subscribing on every render).
    const pageRef = useRef(page);
    const pagesRef = useRef(pages);
    const busyRef = useRef(false);
    pageRef.current = page;
    pagesRef.current = pages;
    busyRef.current = loading || loadingMore;

    // Infinite scroll: auto-load the next page as the sentinel scrolls in or on scroll.
    const observerRef = useRef(null);
    const setSentinel = useCallback((el) => {
        if (observerRef.current) {
            observerRef.current.disconnect();
            observerRef.current = null;
        }
        if (!el) return;
        const rootEl = el.closest('.overflow-y-auto');
        observerRef.current = new IntersectionObserver(
            ([entry]) => {
                if (
                    entry.isIntersecting &&
                    pageRef.current < pagesRef.current &&
                    !busyRef.current
                ) {
                    loadAlbums(pageRef.current + 1, true);
                }
            },
            { root: rootEl, rootMargin: '600px' }
        );
        observerRef.current.observe(el);
    }, []);

    const handleScroll = (e) => {
        const { scrollTop, clientHeight, scrollHeight } = e.target;
        if (
            scrollHeight - (scrollTop + clientHeight) < 600 &&
            pageRef.current < pagesRef.current &&
            !busyRef.current
        ) {
            loadAlbums(pageRef.current + 1, true);
        }
    };

    useEffect(() => () => observerRef.current?.disconnect(), []);

    useEffect(() => {
        loadAlbums(1, false);
    }, []);

    // Open an album when navigated here from search.
    useEffect(() => {
        if (focusAlbumId) {
            openAlbum({ id: focusAlbumId });
            onClearFocus?.();
        }
    }, [focusAlbumId]);

    const loadAlbums = async (pageNum = 1, append = false) => {
        if (append) setLoadingMore(true);
        else setLoading(true);
        try {
            const data = await getAlbums(pageNum, PAGE_SIZE);
            const list = data.albums || [];
            setAlbums(prev => append ? [...prev, ...list] : list);
            setPage(data.page || pageNum);
            setPages(data.pages || 1);
            setTotal(data.total || 0);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
            setLoadingMore(false);
        }
    };

    const openAlbum = async (album) => {
        setLoading(true);
        try {
            const details = await getAlbum(album.id);
            setSelected(details);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const handleRescan = async () => {
        setScanning(true);
        try {
            await scanTelegramChannel(false);
            await loadAlbums(1, false);
        } catch (err) {
            console.error(err);
        } finally {
            setScanning(false);
        }
    };

    if (selected) {
        return (
            <div className="h-full flex flex-col p-8 overflow-y-auto">
                <div className="max-w-5xl mx-auto w-full">
                    <button onClick={() => setSelected(null)} className="mb-6 flex items-center gap-2 text-white/50 hover:text-white transition">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
                        Back to Albums
                    </button>
                    <div className="flex items-end gap-6 mb-8">
                        <div className="w-48 h-48 rounded-xl bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center shadow-2xl overflow-hidden">
                            {selected.cover_art ? (
                                <img src={selected.cover_art} className="w-full h-full object-cover" alt="" />
                            ) : (
                                <svg className="w-20 h-20 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                            )}
                        </div>
                        <div>
                            <p className="text-white/60 uppercase tracking-widest text-xs font-bold mb-1">Album</p>
                            <div className="flex items-center gap-2">
                                <h1 className="text-5xl font-bold mb-2">{selected.name}</h1>
                                {onAddAlbumToPlaylist && (
                                    <AlbumMenu
                                        songIds={(selected.songs || []).map(s => s.id)}
                                        onAddAlbumToPlaylist={onAddAlbumToPlaylist}
                                        className="mb-2"
                                    />
                                )}
                            </div>
                            {selected.artist && <p className="text-white/60">{selected.artist}</p>}
                            <p className="text-white/60">{selected.song_count || selected.songs?.length || 0} songs • from Telegram</p>
                        </div>
                    </div>
                    <div className="space-y-1">
                        {(selected.songs || []).map((song, idx) => (
                            <div key={song.id} className="flex items-center gap-4 p-3 rounded-lg hover:bg-white/5 transition cursor-pointer" onClick={() => onPlaySong(song)}>
                                <span className="text-white/30 w-8 text-center">{idx + 1}</span>
                                <div className="flex-1 min-w-0">
                                    <p className="font-medium text-white truncate">{song.title}</p>
                                    <p className="text-sm text-white/50 truncate">{song.artist}</p>
                                </div>
                                <span className="text-white/30 text-sm">{song.duration ? `${Math.floor(song.duration / 60)}:${(song.duration % 60).toString().padStart(2, '0')}` : ''}</span>
                            </div>
                        ))}
                        {(!selected.songs || selected.songs.length === 0) && (
                            <div className="text-center py-20 text-white/30">This album is empty.</div>
                        )}
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="h-full flex flex-col p-8 overflow-y-auto" onScroll={handleScroll}>
            <div className="max-w-6xl mx-auto w-full">
                <div className="flex items-center justify-between mb-8">
                    <div>
                        <h1 className="text-3xl font-bold">Albums</h1>
                        <p className="text-white/50 text-sm mt-1">Grouped from your Telegram channel library{total > 0 ? ` • ${total} albums` : ''}</p>
                    </div>
                    <button
                        onClick={handleRescan}
                        disabled={scanning}
                        className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 transition text-sm disabled:opacity-50"
                    >
                        {scanning ? 'Scanning...' : 'Rescan channel'}
                    </button>
                </div>
                {loading ? (
                    <div className="flex items-center justify-center py-20">
                        <div className="w-12 h-12 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
                    </div>
                ) : albums.length === 0 ? (
                    <div className="text-center py-20 text-white/40">
                        <p className="text-xl mb-2">No albums yet</p>
                        <p className="text-sm">Add music to the Telegram source channel, then rescan.</p>
                    </div>
                ) : (
                    <>
                    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                        {albums.map(album => (
                            <div key={album.id} onClick={() => openAlbum(album)} className="group glass rounded-xl p-4 cursor-pointer hover:bg-white/10 hover:scale-[1.02] transition duration-300">
                                <div className="aspect-square rounded-lg bg-gray-800 mb-4 flex items-center justify-center relative overflow-hidden">
                                    {album.cover_art ? (
                                        <img src={album.cover_art} className="w-full h-full object-cover transform group-hover:scale-110 transition duration-500" alt="" />
                                    ) : (
                                        <svg className="w-16 h-16 text-white/10" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
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
                                <h3 className="font-bold truncate">{album.name}</h3>
                                <p className="text-sm text-white/50">{album.song_count || 0} songs</p>
                            </div>
                        ))}
                    </div>
                    {/* Infinite-scroll sentinel: loads the next page automatically */}
                    {page < pages && (
                        <div ref={setSentinel} className="flex justify-center py-8">
                            <div className="w-8 h-8 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
                        </div>
                    )}
                    </>
                )}
            </div>
        </div>
    );
};

export default Albums;
