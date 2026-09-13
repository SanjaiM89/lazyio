import React, { useState, useEffect, useRef, useCallback } from 'react';
import { getArtists, getArtist } from './api';

const Artists = ({ onPlaySong, onSelectAlbum, focusArtistName, onClearFocus }) => {
    const [artists, setArtists] = useState([]);
    const [selected, setSelected] = useState(null);
    const [loading, setLoading] = useState(true);
    const [loadingMore, setLoadingMore] = useState(false);
    const [page, setPage] = useState(1);
    const [pages, setPages] = useState(1);
    const [total, setTotal] = useState(0);
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
                    loadArtists(pageRef.current + 1, true);
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
            loadArtists(pageRef.current + 1, true);
        }
    };

    useEffect(() => () => observerRef.current?.disconnect(), []);

    useEffect(() => {
        loadArtists(1, false);
    }, []);

    // Open an artist when navigated here from search.
    useEffect(() => {
        if (focusArtistName) {
            openArtist(focusArtistName);
            onClearFocus?.();
        }
    }, [focusArtistName]);

    const loadArtists = async (pageNum = 1, append = false) => {
        if (append) setLoadingMore(true);
        else setLoading(true);
        try {
            const data = await getArtists(pageNum, PAGE_SIZE);
            const list = data.artists || [];
            setArtists(prev => append ? [...prev, ...list] : list);
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

    const openArtist = async (name) => {
        setLoading(true);
        try {
            const details = await getArtist(name);
            setSelected(details);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const formatPlays = (n) => n === 1 ? '1 play' : `${n || 0} plays`;

    if (selected) {
        return (
            <div className="h-full flex flex-col p-8 overflow-y-auto">
                <div className="max-w-5xl mx-auto w-full">
                    <button onClick={() => setSelected(null)} className="mb-6 flex items-center gap-2 text-white/50 hover:text-white transition">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
                        Back to Artists
                    </button>
                    <div className="flex items-end gap-6 mb-8">
                        <div className="w-48 h-48 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center shadow-2xl overflow-hidden flex-shrink-0">
                            {selected.cover_art ? (
                                <img src={selected.cover_art} className="w-full h-full object-cover" alt="" />
                            ) : (
                                <svg className="w-20 h-20 text-white/30" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" /></svg>
                            )}
                        </div>
                        <div>
                            <p className="text-white/60 uppercase tracking-widest text-xs font-bold mb-1">Artist</p>
                            <h1 className="text-5xl font-bold mb-2">{selected.name}</h1>
                            <p className="text-white/60">{selected.song_count || 0} songs • {selected.album_count || 0} albums • {formatPlays(selected.total_plays)}</p>
                        </div>
                    </div>

                    {selected.albums?.length > 0 && (
                        <div className="mb-8">
                            <h2 className="text-xl font-semibold mb-4">Albums</h2>
                            <div className="flex gap-4 overflow-x-auto pb-2">
                                {selected.albums.map((album, i) => {
                                    const clickable = Boolean(album.id && onSelectAlbum);
                                    return (
                                    <div
                                        key={i}
                                        onClick={() => clickable && onSelectAlbum({ id: album.id })}
                                        className={`glass rounded-xl p-3 w-36 flex-shrink-0 ${clickable ? 'cursor-pointer hover:bg-white/10 hover:scale-[1.02] transition' : ''}`}
                                        title={clickable ? 'Open album' : undefined}
                                    >
                                        <div className="aspect-square rounded-lg bg-gray-800 mb-2 flex items-center justify-center overflow-hidden">
                                            {album.cover_art ? (
                                                <img src={album.cover_art} className="w-full h-full object-cover" alt="" />
                                            ) : (
                                                <svg className="w-10 h-10 text-white/10" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                                            )}
                                        </div>
                                        <p className="font-bold text-sm truncate">{album.name}</p>
                                        <p className="text-xs text-white/50">{album.year || '—'} • {album.song_count} songs</p>
                                        {clickable && (
                                            <p className="text-[11px] text-pink-400/80 mt-1 flex items-center gap-1">
                                                Open
                                                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" /></svg>
                                            </p>
                                        )}
                                    </div>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                    <h2 className="text-xl font-semibold mb-4">Songs</h2>
                    <div className="space-y-1">
                        {(selected.songs || []).map((song, idx) => (
                            <div key={song.id} className="flex items-center gap-4 p-3 rounded-lg hover:bg-white/5 transition cursor-pointer" onClick={() => onPlaySong(song)}>
                                <span className="text-white/30 w-8 text-center">{idx + 1}</span>
                                <div className="flex-1 min-w-0">
                                    <p className="font-medium text-white truncate">{song.title}</p>
                                    <p className="text-sm text-white/50 truncate">{song.album || ''}{song.year ? ` • ${song.year}` : ''}</p>
                                </div>
                                {(song.play_count || 0) > 0 && (
                                    <span className="text-xs bg-pink-500/20 text-pink-300 px-2 py-0.5 rounded-full whitespace-nowrap">{formatPlays(song.play_count)}</span>
                                )}
                                <span className="text-white/30 text-sm">{song.duration ? `${Math.floor(song.duration / 60)}:${(song.duration % 60).toString().padStart(2, '0')}` : ''}</span>
                            </div>
                        ))}
                        {(!selected.songs || selected.songs.length === 0) && (
                            <div className="text-center py-20 text-white/30">No songs for this artist.</div>
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
                        <h1 className="text-3xl font-bold">Artists</h1>
                        <p className="text-white/50 text-sm mt-1">From your Telegram channel library{total > 0 ? ` • ${total} artists` : ''}</p>
                    </div>
                </div>
                {loading ? (
                    <div className="flex items-center justify-center py-20">
                        <div className="w-12 h-12 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
                    </div>
                ) : artists.length === 0 ? (
                    <div className="text-center py-20 text-white/40">
                        <p className="text-xl mb-2">No artists yet</p>
                        <p className="text-sm">Add music to the Telegram source channel, then rescan.</p>
                    </div>
                ) : (
                    <>
                    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                        {artists.map(artist => (
                            <div key={artist.key} onClick={() => openArtist(artist.name)} className="group glass rounded-xl p-4 cursor-pointer hover:bg-white/10 hover:scale-[1.02] transition duration-300">
                                <div className="aspect-square rounded-full bg-gray-800 mb-4 flex items-center justify-center overflow-hidden mx-auto w-3/4">
                                    {artist.cover_art ? (
                                        <img src={artist.cover_art} className="w-full h-full object-cover transform group-hover:scale-110 transition duration-500" alt="" />
                                    ) : (
                                        <svg className="w-16 h-16 text-white/10" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" /></svg>
                                    )}
                                </div>
                                <h3 className="font-bold truncate text-center">{artist.name}</h3>
                                <p className="text-sm text-white/50 text-center">{artist.song_count || 0} songs</p>
                            </div>
                        ))}
                    </div>
                    {/* Infinite-scroll sentinel: loads the next page automatically */}
                    {page < pages && (
                        <div ref={setSentinel} className="flex justify-center py-8">
                            {loadingMore && (
                                <div className="w-8 h-8 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
                            )}
                        </div>
                    )}
                    </>
                )}
            </div>
        </div>
    );
};

export default Artists;
