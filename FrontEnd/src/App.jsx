import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  getSongsPaginated, getHomepage, getWsUrl, recordPlay, deleteSong,
  getStreamUrl, getVideoStreamUrl, getSimilarSongs, getPlaylists,
} from './api';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import QueueSidebar from './components/QueueSidebar';
import PlayerBar from './components/PlayerBar';
import { AddToPlaylistModal, SongMenu, SettingsModal } from './components/Modals';
import FullPlayer from './components/NocturnePlayer';
import { HomeView, SongsView, AlbumsGridView, AlbumDetailView, ArtistsView, PlaylistsView, SearchView, VideosView, UploadView, LibraryView } from './views/Views';

const fmt = (s) => {
  if (!s || isNaN(s)) return '0:00';
  return `${Math.floor(s / 60)}:${Math.floor(s % 60).toString().padStart(2, '0')}`;
};

export default function App() {
  const [view, setView] = useState('home');
  const [history, setHistory] = useState(['home']);
  const [hi, setHi] = useState(0);
  const [query, setQuery] = useState('');

  const [songs, setSongs] = useState([]);
  const [homepage, setHomepage] = useState(null);
  const [playlists, setPlaylists] = useState([]);
  const [currentSong, setCurrentSong] = useState(null);
  const [queue, setQueue] = useState([]);
  const [qi, setQi] = useState(-1);
  const [suggestions, setSuggestions] = useState([]);

  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [libLoading, setLibLoading] = useState(false);

  const [albumFocus, setAlbumFocus] = useState(null);
  const [artistFocus, setArtistFocus] = useState(null);
  const [playlistSignal, setPlaylistSignal] = useState(null);

  const [modalSong, setModalSong] = useState(null);
  const [modalIds, setModalIds] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [menuCtx, setMenuCtx] = useState(null);
  const [settingsOpen, setSettingsOpen] = useState(false);

  const [qtab, setQtab] = useState('queue');
  const [expanded, setExpanded] = useState(false);
  const [shuffle, setShuffle] = useState(false);
  const [repeat, setRepeat] = useState(false);

  // audio state
  const audioRef = useRef(null);
  const videoRef = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(0.8);
  const [mode, setMode] = useState('audio');

  const navigate = (v) => {
    if (v === 'settings') { setSettingsOpen(true); return; }
    setView(v);
    setHistory((h) => [...h.slice(0, hi + 1), v]);
    setHi((i) => i + 1);
  };
  const back = () => { if (hi > 0) { setHi(hi - 1); setView(history[hi - 1]); } };
  const fwd = () => { if (hi < history.length - 1) { setHi(hi + 1); setView(history[hi + 1]); } };

  const loadSongs = async (p = 1, append = false) => {
    if (append && (libLoading || !hasMore)) return;
    setLibLoading(true);
    try {
      const d = await getSongsPaginated(p, 50);
      setSongs((prev) => (append ? [...prev, ...d.songs] : d.songs));
      setHasMore(p < d.pages);
      setPage(p);
      if (!append && d.songs?.length) setQueue((q) => (q.length ? q : d.songs));
    } catch (e) { console.error(e); } finally { setLibLoading(false); }
  };
  const loadHome = async () => { try { setHomepage(await getHomepage()); } catch (e) { console.error(e); } };
  const loadPlaylists = async () => { try { setPlaylists((await getPlaylists(1, 20)).playlists || []); } catch (e) { console.error(e); } };

  useEffect(() => {
    loadSongs(1); loadHome(); loadPlaylists();
    let alive = true, ws = null, retry = 0, timer = null;
    const connect = () => {
      if (!alive) return;
      try { ws = new WebSocket(getWsUrl()); } catch { sched(); return; }
      ws.onopen = () => { retry = 0; };
      ws.onmessage = (e) => { if (e.data === 'library_updated') { loadSongs(1); loadHome(); } };
      ws.onerror = () => { try { ws.close(); } catch {} };
      ws.onclose = sched;
    };
    const sched = () => { if (!alive) return; retry += 1; clearTimeout(timer); timer = setTimeout(connect, Math.min(1000 * 2 ** Math.min(retry, 5), 30000)); };
    connect();
    return () => { alive = false; clearTimeout(timer); try { ws?.close(); } catch {} };
  }, []);

  // autoplay suggestions
  useEffect(() => {
    if (!currentSong) return;
    getSimilarSongs(currentSong.id, 6).then((d) => setSuggestions(d.similar || d.songs || [])).catch(() => {});
  }, [currentSong?.id]);

  // audio element wiring
  useEffect(() => {
    const a = audioRef.current;
    if (!a || !currentSong) return;
    setProgress(0);
    setDuration(currentSong.duration || 0);
    setMode('audio');
    const t = setTimeout(() => { a.play().then(() => setIsPlaying(true)).catch(() => setIsPlaying(false)); }, 60);
    recordPlay(currentSong.id).catch(() => {});
    return () => clearTimeout(t);
  }, [currentSong?.id]);

  useEffect(() => { if (audioRef.current) audioRef.current.volume = volume; }, [volume]);

  const play = useCallback((song, list) => {
    const q = list || queue.length ? (list || queue) : songs;
    const idx = q.findIndex((s) => s.id === song.id);
    setQueue(q);
    setQi(idx >= 0 ? idx : 0);
    setCurrentSong(song);
    setIsPlaying(true);
  }, [queue, songs]);

  const next = useCallback(() => {
    const q = queue.length ? queue : songs;
    if (!q.length) return;
    let n;
    if (shuffle) n = Math.floor(Math.random() * q.length);
    else n = qi + 1 >= q.length ? (repeat ? 0 : qi) : qi + 1;
    if (n === qi && !repeat && n === q.length - 1) { setIsPlaying(false); audioRef.current?.pause(); return; }
    setQi(n); setCurrentSong(q[n]); setIsPlaying(true);
  }, [queue, songs, qi, shuffle, repeat]);

  const prev = useCallback(() => {
    const q = queue.length ? queue : songs;
    if (!q.length) return;
    const n = qi <= 0 ? q.length - 1 : qi - 1;
    setQi(n); setCurrentSong(q[n]); setIsPlaying(true);
  }, [queue, songs, qi]);

  const toggle = () => {
    const a = audioRef.current;
    if (!a || !currentSong) return;
    if (isPlaying) { a.pause(); setIsPlaying(false); }
    else { a.play().then(() => setIsPlaying(true)).catch(() => {}); }
  };

  const onTime = () => {
    const a = audioRef.current;
    if (!a) return;
    setProgress(a.currentTime);
    if (a.duration && isFinite(a.duration)) setDuration(a.duration);
  };
  const onSeek = (e) => { const t = parseFloat(e.target.value); if (audioRef.current) { audioRef.current.currentTime = t; setProgress(t); } };

  const openAddSingle = (song) => { setModalSong(song); setModalIds(null); setModalOpen(true); };
  const openAddAlbum = (album) => {
    const ids = (album.songs || []).map((s) => s.id).filter(Boolean);
    if (!ids.length && album.song_ids?.length) { setModalIds(album.song_ids); }
    else if (ids.length) setModalIds(ids);
    else return;
    setModalSong(null); setModalOpen(true);
  };
  const delSong = async (s) => { try { await deleteSong(s.id); loadSongs(1); loadHome(); } catch (e) { console.error(e); } };

  const hasVideo = currentSong?.has_video || currentSong?.hasVideo;

  return (
    <div className="bg-background text-on-surface min-h-screen font-body-md text-body-md antialiased">
      <Sidebar
        view={view} onNavigate={navigate}
        query={query} setQuery={setQuery} songs={songs}
        onPlay={(s) => play(s)}
        onOpenAlbum={(a) => { setAlbumFocus(a.id); navigate('album'); }}
        onOpenArtist={(a) => { setArtistFocus(a.name); navigate('artists'); }}
        playlists={playlists}
        onOpenPlaylist={(p) => { setPlaylistSignal(p); navigate('playlists'); }}
        onCreatePlaylist={() => navigate('playlists')}
      />
      <QueueSidebar
        currentSong={currentSong} queue={queue.slice(Math.max(0, qi + 1)).concat(queue.slice(0, Math.max(0, qi + 1)).length ? [] : [])}
        suggestions={suggestions} onPlay={(s) => play(s)}
        tab={qtab} setTab={setQtab} isPlaying={isPlaying}
      />
      <div className="pl-64 pr-80 min-h-screen flex flex-col">
        <Header view={view} onNavigate={navigate} onBack={back} onForward={fwd} />
        <main className="relative pt-16 pb-28 w-full px-margin flex-1">
          {view === 'home' && <HomeView data={homepage} onPlay={(s) => play(s, homepage?.ai_playlist?.songs?.length ? undefined : songs)} currentId={currentSong?.id} onOpenAlbum={(a) => { setAlbumFocus(a.id); navigate('album'); }} onRefresh={() => { loadHome(); loadSongs(1); }} onMenu={(s) => setMenuCtx(s)} />}
          {view === 'search' && <SearchView query={query} songs={songs} onPlay={(s) => play(s)} currentId={currentSong?.id} onMenu={(s) => setMenuCtx(s)} onOpenAlbum={(a) => { setAlbumFocus(a.id); navigate('album'); }} onOpenArtist={(a) => { setArtistFocus(a.name); navigate('artists'); }} />}
          {view === 'library' && <LibraryView songs={songs} currentId={currentSong?.id} onPlay={(s) => play(s)} onMenu={(s) => setMenuCtx(s)} onLoadMore={() => loadSongs(page + 1, true)} hasMore={hasMore} loading={libLoading} />}
          {view === 'songs' && <SongsView songs={songs} currentId={currentSong?.id} onPlay={(s) => play(s)} onMenu={(s) => setMenuCtx(s)} onLoadMore={() => loadSongs(page + 1, true)} hasMore={hasMore} loading={libLoading} />}
          {view === 'albums-grid' && <AlbumsGridView onOpen={(a) => { setAlbumFocus(a.id); navigate('album'); }} onAddAlbum={openAddAlbum} />}
          {view === 'albums' && <AlbumsGridView onOpen={(a) => { setAlbumFocus(a.id); navigate('album'); }} onAddAlbum={openAddAlbum} />}
          {view === 'album' && albumFocus && <AlbumDetailView albumId={albumFocus} onBack={() => navigate('albums-grid')} currentId={currentSong?.id} onPlay={play} onAddAlbum={openAddAlbum} onMenu={(s) => setMenuCtx(s)} />}
          {view === 'artists' && <ArtistsView onPlay={play} focusName={artistFocus} onClearFocus={() => setArtistFocus(null)} onOpenAlbum={(a) => { setAlbumFocus(a.id); navigate('album'); }} />}
          {view === 'playlists' && <PlaylistsView onPlay={play} currentId={currentSong?.id} onMenu={(s) => setMenuCtx(s)} openSignal={playlistSignal} onOpened={() => setPlaylistSignal(null)} />}
          {view === 'videos' && <VideosView songs={songs} onPlay={(s) => play(s)} />}
          {view === 'upload' && <UploadView onDone={() => { loadSongs(1); loadHome(); }} />}
        </main>
      </div>

      <PlayerBar
        currentSong={currentSong} isPlaying={isPlaying}
        progress={progress} duration={duration} volume={volume} setVolume={setVolume}
        onToggle={toggle} onNext={next} onPrev={prev} onSeek={onSeek}
        onExpand={() => setExpanded(true)}
        shuffle={shuffle} setShuffle={setShuffle} repeat={repeat} setRepeat={setRepeat}
      />

      {expanded && (
        <FullPlayer
          song={currentSong} isPlaying={isPlaying} progress={progress} duration={duration}
          volume={volume} setVolume={setVolume}
          onToggle={toggle} onNext={next} onPrev={prev} onSeek={onSeek}
          onClose={() => setExpanded(false)} queue={queue} onPlay={(s) => play(s)}
          suggestions={suggestions}
          shuffle={shuffle} setShuffle={setShuffle} repeat={repeat} setRepeat={setRepeat}
          onAdd={openAddSingle}
          hasVideo={hasVideo} mode={mode} setMode={setMode} videoRef={videoRef} audioRef={audioRef} formatTime={fmt}
        />
      )}

      <audio
        ref={audioRef}
        src={currentSong ? getStreamUrl(currentSong.id) : undefined}
        onTimeUpdate={onTime}
        onEnded={next}
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
        style={{ display: 'none' }}
      />

      <AddToPlaylistModal open={modalOpen} onClose={() => setModalOpen(false)} song={modalSong} songIds={modalIds} />
      <SettingsModal open={settingsOpen} onClose={() => setSettingsOpen(false)} />
      {menuCtx && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60" onClick={() => setMenuCtx(null)}>
          <div className="w-64 rounded-2xl bg-surface-container-high border border-white/10 p-2" onClick={(e) => e.stopPropagation()}>
            <p className="px-3 py-2 font-label-md text-label-md truncate">{menuCtx.title}</p>
            <button onClick={() => { openAddSingle(menuCtx); setMenuCtx(null); }} className="w-full text-left px-3 py-2 rounded-lg hover:bg-white/10 font-label-md text-label-md" type="button">Add to playlist</button>
            <button onClick={() => { play(menuCtx); setMenuCtx(null); }} className="w-full text-left px-3 py-2 rounded-lg hover:bg-white/10 font-label-md text-label-md" type="button">Play now</button>
            <button onClick={() => { delSong(menuCtx); setMenuCtx(null); }} className="w-full text-left px-3 py-2 rounded-lg hover:bg-error-container/40 text-error font-label-md text-label-md" type="button">Delete</button>
          </div>
        </div>
      )}
      {/* hidden SongMenu compat */}
      <span className="hidden"><SongMenu song={currentSong} onAdd={openAddSingle} onDelete={delSong} /></span>
    </div>
  );
}
