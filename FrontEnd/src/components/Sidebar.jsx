import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Icon, SectionLabel, Cover } from './ui';
import { suggestLibrary } from '../api';
import { makeSongIndex, fuzzySongs } from './search';

const NavLink = ({ active, icon, label, onClick, accent = false }) => (
  <button
    onClick={onClick}
    className={`w-full flex items-center gap-space-sm px-space-sm py-1.5 rounded-lg transition-all font-label-md text-label-md text-left ${
      active
        ? 'bg-primary-container text-on-primary-container font-semibold'
        : 'text-on-surface-variant hover:bg-surface-container-high hover:text-on-surface'
    }`}
  >
    <Icon name={icon} size={18} className={accent ? 'text-tertiary icon-fill' : ''} fill={accent} />
    {label}
  </button>
);

function SearchBox({ query, setQuery, songs, onNavigate, onPlay, onOpenAlbum, onOpenArtist }) {
  const [open, setOpen] = useState(false);
  const [remote, setRemote] = useState({ albums: [], artists: [] });
  const boxRef = useRef(null);
  const debounceRef = useRef(null);

  const index = useMemo(() => makeSongIndex(songs), [songs]);
  const local = useMemo(() => fuzzySongs(index, query, 5), [index, query]);
  const hasAny = local.length > 0 || remote.albums.length > 0 || remote.artists.length > 0;

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    const q = query.trim();
    if (q.length < 2) { setRemote({ albums: [], artists: [] }); return; }
    debounceRef.current = setTimeout(async () => {
      try {
        const data = await suggestLibrary(q, 5);
        setRemote({ albums: data.albums || [], artists: data.artists || [] });
      } catch { /* keep local results on server failure */ }
    }, 180);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [query]);

  useEffect(() => {
    const close = (e) => { if (boxRef.current && !boxRef.current.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, []);

  const submit = () => { if (query.trim()) { onNavigate('search'); setOpen(false); } };

  return (
    <div className="relative px-space-xs" ref={boxRef}>
      <Icon name="search" size={18} className="absolute left-space-md top-4 -translate-y-1/2 text-outline pointer-events-none" />
      <input
        value={query}
        onChange={(e) => { setQuery(e.target.value); setOpen(true); }}
        onFocus={() => setOpen(true)}
        onKeyDown={(e) => { if (e.key === 'Enter') submit(); if (e.key === 'Escape') setOpen(false); }}
        className="w-full h-8 pl-9 pr-space-md rounded-full bg-surface-container-highest/50 font-body-sm text-body-sm text-on-surface placeholder:text-outline focus:outline-none focus:bg-surface-container-high transition-colors"
        placeholder="Search Library & Music"
        type="text"
      />
      {open && query.trim().length >= 2 && (
        <div className="absolute left-0 right-0 top-full mt-2 rounded-2xl bg-surface-container-high border border-white/10 shadow-2xl overflow-hidden z-50 max-h-[60vh] overflow-y-auto">
          <button onClick={submit} className="w-full px-4 py-2.5 text-left font-label-md text-label-md text-primary hover:bg-white/5 transition flex items-center justify-between gap-2" type="button">
            <span className="truncate">See all results for “{query.trim()}”</span>
            <Icon name="arrow_forward" size={16} />
          </button>
          {remote.artists.length > 0 && (
            <div className="px-2 pb-1">
              <p className="px-2 pt-1 font-label-sm text-label-sm uppercase tracking-wider text-outline">Artists</p>
              {remote.artists.map((a) => (
                <button key={a.key} onClick={() => { onOpenArtist(a); setOpen(false); }} className="w-full flex items-center gap-2.5 p-2 rounded-xl hover:bg-white/5 transition text-left" type="button">
                  <Cover src={a.cover_art} size="w-9 h-9" rounded="rounded-full" icon="artist" />
                  <span className="min-w-0"><span className="block truncate font-label-md text-label-md">{a.name}</span><span className="block truncate font-body-sm text-body-sm text-on-surface-variant">{a.song_count} songs</span></span>
                </button>
              ))}
            </div>
          )}
          {remote.albums.length > 0 && (
            <div className="px-2 pb-1">
              <p className="px-2 pt-1 font-label-sm text-label-sm uppercase tracking-wider text-outline">Albums</p>
              {remote.albums.map((a) => (
                <button key={a.id} onClick={() => { onOpenAlbum(a); setOpen(false); }} className="w-full flex items-center gap-2.5 p-2 rounded-xl hover:bg-white/5 transition text-left" type="button">
                  <Cover src={a.cover_art} size="w-9 h-9" icon="album" />
                  <span className="min-w-0"><span className="block truncate font-label-md text-label-md">{a.name}</span><span className="block truncate font-body-sm text-body-sm text-on-surface-variant">{a.song_count} songs</span></span>
                </button>
              ))}
            </div>
          )}
          {local.length > 0 && (
            <div className="px-2 pb-2">
              <p className="px-2 pt-1 font-label-sm text-label-sm uppercase tracking-wider text-outline">Songs</p>
              {local.map((s) => (
                <button key={s.id} onClick={() => { onPlay(s); setOpen(false); }} className="w-full flex items-center gap-2.5 p-2 rounded-xl hover:bg-white/5 transition text-left" type="button">
                  <Cover src={s.cover_art || s.thumbnail} size="w-9 h-9" />
                  <span className="min-w-0"><span className="block truncate font-label-md text-label-md">{s.title}</span><span className="block truncate font-body-sm text-body-sm text-on-surface-variant">{s.artist}</span></span>
                </button>
              ))}
            </div>
          )}
          {!hasAny && (
            <div className="px-4 py-3 text-center">
              <p className="font-body-sm text-body-sm text-outline mb-2">No quick matches — try the full search</p>
              <button onClick={submit} className="h-8 px-4 rounded-full bg-primary-container text-on-primary-container font-label-md text-label-md" type="button">Search anyway</button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function Sidebar({ view, onNavigate, query, setQuery, songs = [], onPlay, onOpenAlbum, onOpenArtist, playlists = [], onOpenPlaylist, onCreatePlaylist }) {
  return (
    <aside className="fixed left-0 top-0 bottom-0 w-64 bg-surface-container-low/80 backdrop-blur-xl z-30 flex flex-col justify-between p-space-md">
      <div className="flex flex-col space-y-space-md overflow-hidden">
        <div className="flex items-center gap-space-sm px-space-xs pt-space-xs">
          <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <Icon name="graphic_eq" size={20} className="text-on-primary" />
          </div>
          <div className="flex flex-col">
            <span className="font-headline-sm text-headline-sm text-on-surface leading-tight">Lazyio</span>
            <span className="font-label-sm text-label-sm uppercase tracking-wider text-primary">Lossless Audio</span>
          </div>
        </div>

        <SearchBox
          query={query} setQuery={setQuery} songs={songs}
          onNavigate={onNavigate} onPlay={onPlay}
          onOpenAlbum={onOpenAlbum} onOpenArtist={onOpenArtist}
        />

        <div className="flex-1 overflow-y-auto space-y-space-md pr-space-xs">
          <div className="space-y-space-xs">
            <SectionLabel>Discover</SectionLabel>
            <nav className="flex flex-col space-y-0.5">
              <NavLink active={view === 'home'} icon="home" label="Home" onClick={() => onNavigate('home')} />
              <NavLink active={view === 'albums'} icon="explore" label="New & Explore" onClick={() => onNavigate('albums')} />
              <NavLink active={view === 'videos'} icon="radio" label="Music Videos" onClick={() => onNavigate('videos')} />
              <NavLink active={view === 'upload'} icon="confirmation_number" label="Upload" onClick={() => onNavigate('upload')} />
            </nav>
          </div>

          <div className="space-y-space-xs">
            <SectionLabel>Library</SectionLabel>
            <nav className="flex flex-col space-y-0.5">
              <NavLink active={view === 'library'} icon="history" label="Recently Added" onClick={() => onNavigate('library')} />
              <NavLink active={view === 'songs'} icon="music_note" label="Songs" onClick={() => onNavigate('songs')} />
              <NavLink active={view === 'albums-grid'} icon="album" label="Albums" onClick={() => onNavigate('albums-grid')} />
              <NavLink active={view === 'artists'} icon="artist" label="Artists" onClick={() => onNavigate('artists')} />
              <NavLink active={view === 'videos'} icon="movie" label="Music Videos" onClick={() => onNavigate('videos')} />
            </nav>
          </div>

          <div className="space-y-space-xs">
            <div className="flex items-center justify-between px-space-sm">
              <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline">Playlists</span>
              <button onClick={onCreatePlaylist} className="text-outline hover:text-on-surface transition-colors" type="button">
                <Icon name="add" size={16} />
              </button>
            </div>
            <nav className="flex flex-col space-y-0.5">
              <NavLink active={view === 'playlists'} icon="favorite" label="All Playlists" onClick={() => onNavigate('playlists')} accent />
              {playlists.slice(0, 6).map((p) => (
                <NavLink
                  key={p.id}
                  active={false}
                  icon="queue_music"
                  label={p.name}
                  onClick={() => onOpenPlaylist(p)}
                />
              ))}
            </nav>
          </div>
        </div>
      </div>

      <div className="pt-space-md mt-space-xs border-t border-white/[0.06] flex items-center justify-between px-space-xs">
        <div className="flex items-center gap-space-sm">
          <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center">
            <Icon name="person" size={18} className="text-on-primary" />
          </div>
          <div className="flex flex-col">
            <span className="font-label-md text-label-md text-on-surface">Listener</span>
            <span className="font-body-sm text-body-sm text-outline">Hi-Res Lossless</span>
          </div>
        </div>
        <button onClick={() => onNavigate('settings')} className="w-7 h-7 rounded-full flex items-center justify-center text-outline hover:text-on-surface hover:bg-surface-container-high transition-colors" type="button">
          <Icon name="more_horiz" size={18} />
        </button>
      </div>
    </aside>
  );
}
