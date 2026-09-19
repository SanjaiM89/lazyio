import React, { useEffect, useMemo, useState } from 'react';
import { getAlbums, getAlbum, getArtists, getArtist, getPlaylists, getPlaylist, createPlaylist, deletePlaylist, searchLibrary, getSongsPaginated, uploadSongs, deleteSong, scanTelegramChannel } from '../api';
import { Icon, Cover, Badge, EmptyState, fmtTime } from '../components/ui';
import { TrackTable, FilterBar, AlbumHero } from '../components/TrackTable';
import { makeSongIndex, fuzzySongs, mergeSongs } from '../components/search';

/* ---------------- HOME / LISTEN NOW ---------------- */
export function HomeView({ data, onPlay, currentId, onOpenAlbum, onRefresh, onMenu }) {
  const [filter, setFilter] = useState('');
  if (!data) {
    return <div className="flex-1 flex items-center justify-center py-24"><div className="w-12 h-12 rounded-full border-4 border-primary/30 border-t-primary animate-spin" /></div>;
  }
  const recent = data.recently_played || [];
  const ai = data.ai_playlist?.songs || [];
  return (
    <div className="flex flex-col w-full animate-fade-up">
      <div className="relative -mt-16 pt-16 -mx-margin px-margin pb-8 bg-gradient-to-b from-[#3a0d12] via-[#200b0e]/90 to-background overflow-hidden">
        <div className="absolute -top-24 left-1/4 w-[700px] h-[420px] bg-secondary-container/40 blur-[130px] rounded-full pointer-events-none mix-blend-screen" />
        <div className="relative z-10 pt-6 flex items-end justify-between gap-4">
          <div>
            <div className="flex items-center gap-space-xs text-primary font-label-sm text-label-sm uppercase tracking-widest mb-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" /><span>Listen Now</span>
            </div>
            <h1 className="font-display-hero text-display-hero text-on-surface tracking-tight">Welcome Back</h1>
            <p className="font-body-lg text-body-lg text-on-surface-variant mt-1">Your lossless library, freshly synced.</p>
          </div>
          <button onClick={onRefresh} className="h-10 px-5 rounded-full bg-white/[0.08] hover:bg-white/[0.14] text-on-surface font-label-lg flex items-center gap-2 transition-colors" type="button">
            <Icon name="refresh" size={18} /> Refresh
          </button>
        </div>
      </div>

      <div className="flex flex-col gap-space-md pt-4 pb-12">
        {recent.length > 0 && (
          <section>
            <div className="flex items-center justify-between px-space-xs mb-2">
              <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline">Recently Played</span>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-3">
              {recent.slice(0, 5).map((s) => (
                <button key={s.id} onClick={() => onPlay(s)} className="text-left p-3 rounded-xl bg-surface-container hover:bg-surface-container-high transition-colors group">
                  <div className="aspect-square rounded-lg overflow-hidden bg-surface-container-highest mb-2 relative">
                    {s.cover_art ? <img src={s.cover_art} className="w-full h-full object-cover group-hover:scale-105 transition duration-500" alt="" /> : <div className="w-full h-full flex items-center justify-center text-outline"><Icon name="music_note" size={28} /></div>}
                  </div>
                  <p className="font-label-md text-label-md text-on-surface truncate">{s.title}</p>
                  <p className="font-body-sm text-body-sm text-on-surface-variant truncate">{s.artist}</p>
                </button>
              ))}
            </div>
          </section>
        )}

        {ai.length > 0 && (
          <section>
            <div className="flex items-center justify-between px-space-xs mb-2">
              <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline">{data.ai_playlist?.name || 'For You'}</span>
              <Badge tone="lossless">AI Generated</Badge>
            </div>
            <div className="p-2 rounded-2xl bg-surface-container-low">
              <FilterBar value={filter} onChange={setFilter} />
              <TrackTable tracks={ai} currentId={currentId} onPlay={onPlay} onMenu={onMenu} filter={filter} />
            </div>
          </section>
        )}

        {recent.length === 0 && ai.length === 0 && (
          <EmptyState icon="graphic_eq" title="Library is quiet" hint="Upload music or scan your Telegram channel to get started." />
        )}
      </div>
    </div>
  );
}

/* ---------------- SONG LIBRARY ---------------- */
export function SongsView({ songs, currentId, onPlay, onMenu, onLoadMore, hasMore, loading, onDelete }) {
  const [filter, setFilter] = useState('');
  return (
    <div className="flex flex-col gap-space-md pt-20 pb-12 animate-fade-up">
      <div className="flex items-end justify-between">
        <div>
          <div className="flex items-center gap-space-xs text-primary font-label-sm text-label-sm uppercase tracking-widest mb-1"><span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" /><span>Library</span></div>
          <h1 className="font-headline-lg text-headline-lg text-on-surface">Songs</h1>
        </div>
        <span className="font-body-sm text-body-sm text-outline">{songs.length} tracks</span>
      </div>
      <div className="p-2 rounded-2xl bg-surface-container-low">
        <FilterBar value={filter} onChange={setFilter} />
        <TrackTable tracks={songs} currentId={currentId} onPlay={onPlay} onMenu={(s) => onMenu(s, onDelete)} filter={filter} />
        {hasMore && (
          <button onClick={onLoadMore} className="mx-auto my-4 flex h-9 px-5 rounded-full bg-white/[0.08] hover:bg-white/[0.14] items-center gap-2 font-label-md text-label-md" type="button">
            {loading ? 'Loading…' : 'Load more'}
          </button>
        )}
      </div>
    </div>
  );
}

/* ---------------- ALBUMS ---------------- */
export function AlbumsGridView({ onOpen, onAddAlbum }) {
  const [albums, setAlbums] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [scanning, setScanning] = useState(false);

  const load = async (p = 1, append = false) => {
    if (!append) setLoading(true);
    try {
      const d = await getAlbums(p, 60);
      setAlbums((prev) => (append ? [...prev, ...d.albums] : d.albums || []));
      setPage(d.page || p); setPages(d.pages || 1);
    } catch (e) { console.error(e); } finally { setLoading(false); }
  };
  useEffect(() => { load(1); }, []);
  const rescan = async () => { setScanning(true); try { await scanTelegramChannel(false); await load(1); } catch (e) { console.error(e); } finally { setScanning(false); } };

  return (
    <div className="flex flex-col gap-4 pt-20 pb-12 animate-fade-up">
      <div className="flex items-end justify-between">
        <div>
          <div className="flex items-center gap-space-xs text-primary font-label-sm text-label-sm uppercase tracking-widest mb-1"><span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" /><span>Browse</span></div>
          <h1 className="font-headline-lg text-headline-lg text-on-surface">Albums</h1>
        </div>
        <button onClick={rescan} disabled={scanning} className="h-9 px-4 rounded-full bg-white/[0.08] hover:bg-white/[0.14] font-label-md text-label-md disabled:opacity-50" type="button">{scanning ? 'Scanning…' : 'Rescan channel'}</button>
      </div>
      {loading ? <div className="flex justify-center py-20"><div className="w-10 h-10 rounded-full border-4 border-primary/30 border-t-primary animate-spin" /></div>
        : albums.length === 0 ? <EmptyState icon="album" title="No albums yet" hint="Add music to the source channel, then rescan." />
        : (
          <>
            <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
              {albums.map((a) => (
                <button key={a.id} onClick={() => onOpen(a)} className="text-left p-3 rounded-2xl bg-surface-container-low hover:bg-surface-container-high transition group">
                  <div className="aspect-square rounded-xl overflow-hidden bg-surface-container-highest mb-2 relative">
                    {a.cover_art ? <img src={a.cover_art} className="w-full h-full object-cover group-hover:scale-105 transition duration-500" alt="" /> : <div className="w-full h-full flex items-center justify-center text-outline"><Icon name="album" size={40} /></div>}
                    {onAddAlbum && (
                      <span onClick={(e) => { e.stopPropagation(); onAddAlbum(a); }} className="absolute top-2 right-2 w-8 h-8 rounded-full bg-black/60 items-center justify-center hidden group-hover:flex text-on-surface"><Icon name="add" size={16} /></span>
                    )}
                  </div>
                  <p className="font-label-lg text-label-lg text-on-surface truncate">{a.name}</p>
                  <p className="font-body-sm text-body-sm text-on-surface-variant">{a.song_count || 0} songs</p>
                </button>
              ))}
            </div>
            {page < pages && <button onClick={() => load(page + 1, true)} className="mx-auto h-9 px-5 rounded-full bg-white/[0.08] hover:bg-white/[0.14] font-label-md text-label-md" type="button">Load more</button>}
          </>
        )}
    </div>
  );
}

export function AlbumDetailView({ albumId, onBack, currentId, onPlay, onAddAlbum, onMenu }) {
  const [album, setAlbum] = useState(null);
  const [filter, setFilter] = useState('');
  useEffect(() => {
    (async () => {
      try { setAlbum(await getAlbum(albumId)); } catch (e) { console.error(e); }
    })();
  }, [albumId]);
  if (!album) return <div className="flex justify-center py-32"><div className="w-10 h-10 rounded-full border-4 border-primary/30 border-t-primary animate-spin" /></div>;
  const playAll = () => { if (album.songs?.[0]) onPlay(album.songs[0], album.songs); };
  const shuffleAll = () => { const l = [...(album.songs || [])].sort(() => Math.random() - 0.5); if (l[0]) onPlay(l[0], l); };
  return (
    <div className="flex flex-col w-full animate-fade-up">
      <button onClick={onBack} className="absolute top-20 z-10 flex items-center gap-2 text-on-surface-variant hover:text-on-surface font-label-md text-label-md" type="button">
        <Icon name="arrow_back" size={18} /> Back
      </button>
      <AlbumHero album={album} onPlay={playAll} onShuffle={shuffleAll} onAdd={() => onAddAlbum(album)} />
      <div className="flex flex-col gap-space-md pt-6 pb-12">
        <div className="p-2 rounded-2xl bg-surface-container-low">
          <FilterBar value={filter} onChange={setFilter} />
          <TrackTable tracks={album.songs || []} currentId={currentId} onPlay={(s) => onPlay(s, album.songs)} onMenu={onMenu} filter={filter} />
        </div>
        <div className="mt-2 pt-6 border-t border-white/[0.06] grid grid-cols-1 md:grid-cols-3 gap-space-lg">
          <div className="md:col-span-2">
            <h3 className="font-headline-sm text-headline-sm text-on-surface mb-2">About the Album</h3>
            <p className="font-body-md text-body-md text-on-surface-variant leading-relaxed">{album.name} — {album.song_count || album.songs?.length || 0} tracks in lossless quality, streamed from your self-hosted library.</p>
          </div>
          <div className="p-space-md rounded-xl bg-surface-container-low flex flex-col justify-between">
            <div>
              <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline block mb-2">Master Quality Authenticated</span>
              <div className="flex items-center gap-space-xs text-primary mb-1"><Icon name="high_quality" size={20} /><span className="font-label-md text-label-md text-on-surface">Lossless Stream</span></div>
              <p className="font-body-sm text-body-sm text-outline">Stereo • Bit-perfect output</p>
            </div>
            <div className="pt-4 flex items-center justify-between">
              <span className="font-label-sm text-label-sm text-on-surface-variant">DAC Sync Rate</span>
              <span className="px-2 py-0.5 rounded bg-surface-container-highest font-mono text-[11px] text-primary">Bit-Perfect</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------------- ARTISTS ---------------- */
export function ArtistsView({ onPlay, focusName, onClearFocus, onOpenAlbum }) {
  const [artists, setArtists] = useState([]);
  const [selected, setSelected] = useState(null);
  const [q, setQ] = useState('');
  useEffect(() => { (async () => { try { setArtists((await getArtists(1, 100)).artists || []); } catch (e) { console.error(e); } })(); }, []);
  useEffect(() => { if (focusName) { openArtist(focusName); onClearFocus?.(); } }, [focusName]);
  const openArtist = async (name) => { try { setSelected(await getArtist(typeof name === 'string' ? name : name.name)); } catch (e) { console.error(e); } };
  const list = q ? artists.filter((a) => a.name.toLowerCase().includes(q.toLowerCase())) : artists;

  if (selected) {
    return (
      <div className="flex flex-col w-full animate-fade-up">
        <div className="relative -mt-16 pt-16 -mx-margin px-margin pb-8 bg-gradient-to-b from-[#4e0e13] via-[#240c10]/90 to-background overflow-hidden">
          <div className="absolute -top-24 left-1/4 w-[700px] h-[420px] bg-secondary-container/40 blur-[130px] rounded-full pointer-events-none" />
          <div className="relative z-10 pt-14 flex items-end gap-6">
            <button onClick={() => setSelected(null)} className="absolute top-20 flex items-center gap-2 text-on-surface-variant hover:text-on-surface font-label-md" type="button"><Icon name="arrow_back" size={18} /> Back</button>
            <div className="w-40 h-40 rounded-2xl overflow-hidden bg-surface-container-highest flex items-center justify-center text-outline">
              {selected.cover_art ? <img src={selected.cover_art} className="w-full h-full object-cover" alt="" /> : <Icon name="artist" size={48} />}
            </div>
            <div>
              <div className="flex items-center gap-space-xs text-primary font-label-sm text-label-sm uppercase tracking-widest mb-1"><span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" /><span>Artist</span></div>
              <h1 className="font-display-hero text-display-hero truncate">{selected.name}</h1>
              <p className="font-body-md text-body-md text-on-surface-variant">{selected.song_count || selected.songs?.length || 0} songs • {selected.album_count || 0} albums</p>
            </div>
          </div>
        </div>
        <div className="p-2 rounded-2xl bg-surface-container-low mt-4 mb-12">
          <TrackTable tracks={selected.songs || []} onPlay={(s) => onPlay(s, selected.songs)} />
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4 pt-20 pb-12 animate-fade-up">
      <h1 className="font-headline-lg text-headline-lg">Artists</h1>
      <div className="relative max-w-xs">
        <Icon name="search" size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-outline" />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Filter artists…" className="w-full h-9 pl-9 pr-3 rounded-full bg-surface-container font-body-sm text-body-sm placeholder:text-outline focus:outline-none" />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-5 gap-4">
        {list.map((a) => (
          <button key={a.name} onClick={() => openArtist(a.name)} className="p-4 rounded-2xl bg-surface-container-low hover:bg-surface-container-high transition text-center">
            <div className="w-20 h-20 mx-auto rounded-full overflow-hidden bg-surface-container-highest mb-2 flex items-center justify-center text-outline">
              {a.cover_art ? <img src={a.cover_art} className="w-full h-full object-cover" alt="" /> : <Icon name="artist" size={28} />}
            </div>
            <p className="font-label-lg text-label-lg truncate">{a.name}</p>
            <p className="font-body-sm text-body-sm text-on-surface-variant">{a.song_count || 0} songs</p>
          </button>
        ))}
      </div>
      {list.length === 0 && <EmptyState icon="artist" title="No artists found" />}
    </div>
  );
}

/* ---------------- PLAYLISTS ---------------- */
export function PlaylistsView({ onPlay, currentId, onMenu, openSignal, onOpened }) {
  const [playlists, setPlaylists] = useState([]);
  const [selected, setSelected] = useState(null);
  const [name, setName] = useState('');
  const load = async () => { try { setPlaylists((await getPlaylists(1, 50)).playlists || []); } catch (e) { console.error(e); } };
  useEffect(() => { load(); }, []);
  useEffect(() => { if (openSignal) { openPlaylist(openSignal); onOpened?.(); } }, [openSignal]);
  const openPlaylist = async (p) => { try { setSelected(await getPlaylist(p.id)); } catch (e) { console.error(e); } };
  const create = async () => { if (!name.trim()) return; try { await createPlaylist(name.trim()); setName(''); load(); } catch (e) { console.error(e); } };
  const remove = async (id) => { try { await deletePlaylist(id); setSelected(null); load(); } catch (e) { console.error(e); } };

  if (selected) {
    return (
      <div className="flex flex-col w-full animate-fade-up">
        <div className="relative -mt-16 pt-16 -mx-margin px-margin pb-8 bg-gradient-to-b from-[#3d1a10] via-[#241210]/90 to-background overflow-hidden">
          <div className="absolute -top-24 left-1/4 w-[700px] h-[420px] bg-primary-container/20 blur-[130px] rounded-full pointer-events-none" />
          <div className="relative z-10 pt-14 flex items-end gap-6">
            <button onClick={() => { setSelected(null); load(); }} className="absolute top-20 flex items-center gap-2 text-on-surface-variant hover:text-on-surface font-label-md" type="button"><Icon name="arrow_back" size={18} /> Back</button>
            <div className="w-40 h-40 rounded-2xl bg-primary-container flex items-center justify-center"><Icon name="queue_music" size={48} className="text-on-primary-container" /></div>
            <div className="flex-1">
              <div className="flex items-center gap-space-xs text-primary font-label-sm text-label-sm uppercase tracking-widest mb-1"><span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" /><span>Playlist</span></div>
              <h1 className="font-display-hero text-display-hero truncate">{selected.name}</h1>
              <p className="font-body-md text-body-md text-on-surface-variant">{selected.songs?.length || 0} tracks</p>
              <div className="flex gap-2 mt-3">
                <button onClick={() => selected.songs?.[0] && onPlay(selected.songs[0], selected.songs)} className="h-10 px-6 rounded-full bg-primary-container text-on-primary-container font-label-lg flex items-center gap-2" type="button"><Icon name="play_arrow" size={20} fill /> Play</button>
                <button onClick={() => remove(selected.id)} className="h-10 px-4 rounded-full bg-white/[0.08] hover:bg-white/[0.14] font-label-lg flex items-center gap-2" type="button"><Icon name="delete" size={18} /> Delete</button>
              </div>
            </div>
          </div>
        </div>
        <div className="p-2 rounded-2xl bg-surface-container-low mt-4 mb-12">
          <TrackTable tracks={selected.songs || []} currentId={currentId} onPlay={(s) => onPlay(s, selected.songs)} onMenu={onMenu} />
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4 pt-20 pb-12 animate-fade-up">
      <h1 className="font-headline-lg text-headline-lg">Playlists</h1>
      <div className="flex gap-2 max-w-md">
        <input value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && create()} placeholder="New playlist name…" className="flex-1 h-10 px-4 rounded-full bg-surface-container font-body-md text-body-md placeholder:text-outline focus:outline-none" />
        <button onClick={create} className="h-10 px-5 rounded-full bg-primary-container text-on-primary-container font-label-lg flex items-center gap-1" type="button"><Icon name="add" size={18} /> Create</button>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
        {playlists.map((p) => (
          <button key={p.id} onClick={() => openPlaylist(p)} className="text-left p-4 rounded-2xl bg-surface-container-low hover:bg-surface-container-high transition flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-surface-container-highest flex items-center justify-center text-primary"><Icon name="queue_music" size={22} /></div>
            <div className="min-w-0"><p className="font-label-lg text-label-lg truncate">{p.name}</p><p className="font-body-sm text-body-sm text-on-surface-variant">{p.song_count ?? p.songs?.length ?? 0} tracks</p></div>
          </button>
        ))}
      </div>
      {playlists.length === 0 && <EmptyState icon="queue_music" title="No playlists yet" hint="Create one above, or add songs via the ••• menu." />}
    </div>
  );
}

/* ---------------- SEARCH ---------------- */
export function SearchView({ query, songs: librarySongs = [], onPlay, currentId, onMenu, onOpenAlbum, onOpenArtist }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  useEffect(() => {
    if (!query.trim()) { setData(null); setError(false); return; }
    setLoading(true);
    setError(false);
    const t = setTimeout(async () => {
      try {
        setData(await searchLibrary(query.trim(), 30, 8, 8));
      } catch (e) {
        console.error(e);
        setError(true);
        setData({ songs: [], albums: [], artists: [] });
      } finally { setLoading(false); }
    }, 300);
    return () => clearTimeout(t);
  }, [query]);
  // Client-side typo-tolerant fallback merged under server hits, so even
  // songs missing from the server response (or a failed request) surface.
  const index = useMemo(() => makeSongIndex(librarySongs), [librarySongs]);
  const fallback = useMemo(() => fuzzySongs(index, query, 10), [index, query]);
  const allSongs = mergeSongs(data?.songs, fallback);
  const total = allSongs.length + (data?.albums?.length || 0) + (data?.artists?.length || 0);
  return (
    <div className="flex flex-col gap-4 pt-20 pb-12 animate-fade-up">
      <div>
        <h1 className="font-headline-lg text-headline-lg">Results for “{query}”</h1>
        {data && !loading && (
          <p className="font-body-sm text-body-sm text-outline mt-1">
            Found {allSongs.length} song{allSongs.length !== 1 ? 's' : ''}, {data.albums?.length || 0} albums, {data.artists?.length || 0} artists
          </p>
        )}
      </div>
      {loading && <div className="flex justify-center py-16"><div className="w-10 h-10 rounded-full border-4 border-primary/30 border-t-primary animate-spin" /></div>}
      {!loading && error && (
        <p className="font-body-sm text-body-sm text-outline px-space-xs">Server search failed — showing offline matches from your loaded library.</p>
      )}
      {!loading && data && (
        <>
          {(data.artists?.length > 0) && (
            <section>
              <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline px-space-xs">Artists</span>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-2">
                {data.artists.slice(0, 4).map((a) => (
                  <button key={a.key} onClick={() => onOpenArtist?.(a)} className="text-left p-3 rounded-xl bg-surface-container-low hover:bg-surface-container-high transition">
                    <Cover src={a.cover_art} size="w-full aspect-square" rounded="rounded-full" icon="artist" />
                    <p className="font-label-md text-label-md truncate mt-2">{a.name}</p>
                    <p className="font-body-sm text-body-sm text-on-surface-variant">{a.song_count} songs</p>
                  </button>
                ))}
              </div>
            </section>
          )}
          {(data.albums?.length > 0) && (
            <section>
              <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline px-space-xs">Albums</span>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-2">
                {data.albums.slice(0, 4).map((a) => (
                  <button key={a.id} onClick={() => onOpenAlbum(a)} className="text-left p-3 rounded-xl bg-surface-container-low hover:bg-surface-container-high transition">
                    <Cover src={a.cover_art} size="w-full aspect-square" rounded="rounded-lg" icon="album" />
                    <p className="font-label-md text-label-md truncate mt-2">{a.name}</p>
                  </button>
                ))}
              </div>
            </section>
          )}
          <section>
            <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline px-space-xs">Songs</span>
            {allSongs.length > 0 ? (
              <div className="p-2 rounded-2xl bg-surface-container-low mt-2">
                <TrackTable tracks={allSongs} currentId={currentId} onPlay={onPlay} onMenu={onMenu} />
              </div>
            ) : (
              <EmptyState icon="search" title="No results found" hint={`Nothing matched "${query}". Check spelling or try an artist name.`} />
            )}
          </section>
          {total === 0 && null}
        </>
      )}
    </div>
  );
}

/* ---------------- VIDEOS ---------------- */
export function VideosView({ songs, onPlay }) {
  const vids = songs.filter((s) => s.has_video || s.hasVideo);
  return (
    <div className="flex flex-col gap-4 pt-20 pb-12 animate-fade-up">
      <h1 className="font-headline-lg text-headline-lg">Music Videos</h1>
      {vids.length === 0
        ? <EmptyState icon="movie" title="No videos in queue" hint="Videos appear here once your library includes tracks with video." />
        : <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {vids.map((s) => (
            <button key={s.id} onClick={() => onPlay(s)} className="text-left rounded-2xl overflow-hidden bg-surface-container-low hover:bg-surface-container-high transition group">
              <div className="aspect-video bg-surface-container-highest relative flex items-center justify-center">
                {s.cover_art ? <img src={s.cover_art} className="absolute inset-0 w-full h-full object-cover" alt="" /> : <Icon name="movie" size={36} className="text-outline" />}
                <span className="relative w-12 h-12 rounded-full bg-black/60 flex items-center justify-center text-white group-hover:scale-110 transition"><Icon name="play_arrow" size={24} fill /></span>
                {s.duration && <span className="absolute bottom-2 right-2 px-1.5 py-0.5 rounded bg-black/70 font-mono text-[11px]">{fmtTime(s.duration)}</span>}
              </div>
              <div className="p-3"><p className="font-label-lg text-label-lg truncate">{s.title}</p><p className="font-body-sm text-body-sm text-on-surface-variant truncate">{s.artist}</p></div>
            </button>
          ))}
        </div>}
    </div>
  );
}

/* ---------------- UPLOAD ---------------- */
export function UploadView({ onDone }) {
  const [progress, setProgress] = useState(null);
  const [drag, setDrag] = useState(false);
  const [msg, setMsg] = useState('');
  const send = async (files) => {
    if (!files?.length) return;
    const fd = new FormData();
    [...files].forEach((f) => fd.append('files', f));
    setProgress(0); setMsg('');
    try {
      await uploadSongs(fd, (p) => setProgress(p));
      setMsg(`Uploaded ${files.length} file(s). Processing…`);
      setProgress(null);
      onDone?.();
    } catch (e) { console.error(e); setMsg('Upload failed. Try again.'); setProgress(null); }
  };
  return (
    <div className="flex flex-col gap-4 pt-20 pb-12 max-w-3xl animate-fade-up">
      <h1 className="font-headline-lg text-headline-lg">Upload</h1>
      <div
        onDragOver={(e) => { e.preventDefault(); setDrag(true); }}
        onDragLeave={() => setDrag(false)}
        onDrop={(e) => { e.preventDefault(); setDrag(false); send(e.dataTransfer.files); }}
        className={`rounded-3xl border-2 border-dashed p-12 text-center transition ${drag ? 'border-primary bg-primary-container/10' : 'border-white/10 bg-surface-container-low'}`}
      >
        <div className="w-14 h-14 mx-auto rounded-2xl bg-surface-container-high flex items-center justify-center text-primary mb-3"><Icon name="upload" size={26} /></div>
        <p className="font-headline-sm text-headline-sm mb-1">Drop audio files here</p>
        <p className="font-body-sm text-body-sm text-outline mb-4">MP3, FLAC, M4A, WAV, OGG — lossless preserved</p>
        <label className="inline-flex h-10 px-6 rounded-full bg-primary-container text-on-primary-container font-label-lg items-center gap-2 cursor-pointer">
          <Icon name="add" size={18} /> Choose files
          <input type="file" multiple accept="audio/*,video/*" className="hidden" onChange={(e) => send(e.target.files)} />
        </label>
        {progress != null && (
          <div className="mt-4 h-1.5 rounded-full bg-surface-container-highest overflow-hidden"><div className="h-full bg-primary transition-all" style={{ width: `${progress}%` }} /></div>
        )}
        {msg && <p className="mt-3 font-body-sm text-body-sm text-on-surface-variant">{msg}</p>}
      </div>
    </div>
  );
}

/* ---------------- LIBRARY (paginated, all songs w/ infinite scroll) ---------------- */
export function LibraryView({ songs, currentId, onPlay, onMenu, onLoadMore, hasMore, loading }) {
  const [filter, setFilter] = useState('');
  return (
    <div className="flex flex-col gap-space-md pt-20 pb-12 animate-fade-up">
      <h1 className="font-headline-lg text-headline-lg">Recently Added</h1>
      <div className="p-2 rounded-2xl bg-surface-container-low">
        <FilterBar value={filter} onChange={setFilter} />
        <TrackTable tracks={songs} currentId={currentId} onPlay={onPlay} onMenu={onMenu} filter={filter} />
        {hasMore && <button onClick={onLoadMore} className="mx-auto my-4 flex h-9 px-5 rounded-full bg-white/[0.08] hover:bg-white/[0.14] items-center font-label-md" type="button">{loading ? 'Loading…' : 'Load more'}</button>}
        {!hasMore && songs.length > 0 && <p className="text-center font-body-sm text-body-sm text-outline py-4">All songs loaded</p>}
      </div>
    </div>
  );
}
