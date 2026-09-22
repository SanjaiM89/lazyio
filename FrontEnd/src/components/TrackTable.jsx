import React from 'react';
import { Icon, Badge, SongBadges, fmtTime } from './ui';

export function TrackTable({ tracks = [], currentId, onPlay, onMenu, filter = '' }) {
  const q = filter.trim().toLowerCase();
  const list = q ? tracks.filter((t) => `${t.title} ${t.artist}`.toLowerCase().includes(q)) : tracks;
  return (
    <div className="flex flex-col w-full space-y-0.5">
      <div className="grid grid-cols-[36px_1fr_100px_64px_40px] items-center px-space-sm py-2 text-outline font-label-sm text-label-sm uppercase tracking-wider">
        <span className="text-center">#</span>
        <span>Title</span>
        <span className="text-right pr-2">Artist</span>
        <span className="text-right">Time</span>
        <span />
      </div>
      {list.map((song, idx) => {
        const active = currentId === song.id;
        return (
          <div
            key={song.id ?? idx}
            onClick={() => onPlay(song)}
            className={`grid grid-cols-[36px_1fr_100px_64px_40px] items-center px-space-sm py-2.5 rounded-lg transition-colors group cursor-pointer ${active ? 'bg-surface-container-high/80' : 'hover:bg-surface-container-high/60'}`}
          >
            <div className="flex items-center justify-center">
              {active ? (
                <div className="flex items-end gap-[2px] h-3.5">
                  {[0, 1, 2].map((i) => (
                    <span key={i} className="w-[2.5px] bg-primary eq-bar" style={{ height: '100%', animationDelay: `${i * 0.2}s` }} />
                  ))}
                </div>
              ) : (
                <>
                  <span className="font-body-sm text-body-sm text-outline group-hover:hidden">{idx + 1}</span>
                  <button className="hidden group-hover:flex text-on-surface" type="button"><Icon name="play_arrow" size={18} /></button>
                </>
              )}
            </div>
            <div className="flex flex-col min-w-0 pr-space-md">
              <div className="flex items-center gap-space-sm min-w-0">
                <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${active ? 'bg-primary' : 'bg-transparent'}`} />
                <span className={`font-body-lg text-body-lg truncate ${active ? 'text-primary font-semibold' : 'text-on-surface font-medium'}`}>
                  {song.title || 'Unknown'}
                </span>
                {active && <span className="px-1.5 rounded bg-surface-container-highest text-primary font-label-sm text-label-sm">NOW</span>}
              </div>
              <SongBadges song={song} compact className="ml-3.5 mt-0.5" />
            </div>
            <div className="text-right pr-2 truncate">
              <span className={`px-2 py-0.5 rounded bg-surface-container font-label-sm text-label-sm font-mono truncate ${active ? 'text-primary' : 'text-on-surface-variant'}`}>
                {(song.artist || '—').slice(0, 12)}
              </span>
            </div>
            <span className={`font-body-sm text-body-sm text-right font-mono ${active ? 'text-primary' : 'text-outline'}`}>{fmtTime(song.duration)}</span>
            <div className={`flex justify-end transition-opacity ${active ? '' : 'opacity-0 group-hover:opacity-100'}`}>
              <button className={active ? 'text-primary' : 'text-outline hover:text-on-surface'} type="button" onClick={(e) => { e.stopPropagation(); onMenu?.(song); }}>
                <Icon name="more_horiz" size={18} />
              </button>
            </div>
          </div>
        );
      })}
      {list.length === 0 && <p className="text-center font-body-sm text-body-sm text-outline py-8">No tracks match.</p>}
    </div>
  );
}

export function FilterBar({ value, onChange }) {
  return (
    <div className="flex items-center justify-between gap-space-md py-2 px-space-xs">
      <div className="relative flex-1 max-w-xs">
        <Icon name="search" size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-outline" />
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-full h-8 pl-9 pr-3 rounded-full bg-surface-container font-body-sm text-body-sm text-on-surface placeholder:text-outline focus:outline-none focus:bg-surface-container-high transition-colors"
          placeholder="Filter tracks..."
          type="text"
        />
      </div>
      <div className="flex items-center gap-space-xs text-outline">
        <button className="w-8 h-8 rounded-lg flex items-center justify-center hover:bg-surface-container-high hover:text-on-surface transition-colors" type="button">
          <Icon name="filter_list" size={18} />
        </button>
        <button className="w-8 h-8 rounded-lg flex items-center justify-center hover:bg-surface-container-high hover:text-on-surface transition-colors" type="button">
          <Icon name="view_column" size={18} />
        </button>
      </div>
    </div>
  );
}

export function AlbumHero({ album, onPlay, onShuffle, onAdd }) {
  const songs = album.songs || [];
  const totalSec = songs.reduce((a, s) => a + (s.duration || 0), 0);
  return (
    <div className="relative -mt-16 pt-16 -mx-margin px-margin pb-10 bg-gradient-to-b from-[#4e0e13] via-[#240c10]/90 to-background overflow-hidden">
      <div className="absolute -top-24 left-1/4 w-[750px] h-[480px] bg-secondary-container/40 blur-[130px] rounded-full pointer-events-none mix-blend-screen" />
      <div className="absolute top-10 right-10 w-[420px] h-[360px] bg-primary-container/15 blur-[100px] rounded-full pointer-events-none" />
      <div className="relative z-10 flex flex-col md:flex-row items-center md:items-end gap-space-xl pt-6">
        <div className="relative group flex-shrink-0 w-64 h-64 md:w-72 md:h-72 rounded-2xl overflow-hidden shadow-[0_24px_50px_rgba(0,0,0,0.7)] bg-surface-container-high transition-transform duration-300 hover:scale-[1.015]">
          {album.cover_art ? (
            <img className="w-full h-full object-cover object-center" src={album.cover_art} alt={album.name} />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-outline"><Icon name="album" size={64} /></div>
          )}
          <div className="absolute inset-0 bg-gradient-to-tr from-black/40 via-transparent to-white/10 pointer-events-none" />
        </div>
        <div className="flex flex-col flex-1 min-w-0 pb-1">
          <div className="flex items-center gap-space-xs text-primary font-label-sm text-label-sm uppercase tracking-widest mb-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" />
            <span>Studio Album</span>
          </div>
          <h1 className="font-display-hero text-display-hero text-on-surface tracking-tight leading-none mb-3 truncate">{album.name}</h1>
          <div className="flex items-center gap-space-sm mb-4">
            <span className="font-label-lg text-label-lg text-on-surface">{album.artist || 'Various Artists'}</span>
            <Icon name="check_circle" size={18} className="text-primary icon-fill" fill />
          </div>
          <div className="flex flex-wrap items-center gap-space-xs mb-6">
            <Badge tone="pill"><Icon name="graphic_eq" size={13} className="text-primary" /> Lossless</Badge>
            <Badge tone="pill"><Icon name="schedule" size={13} /> {songs.length} Tracks</Badge>
            <Badge tone="pill"><Icon name="library_music" size={13} /> {Math.floor(totalSec / 60)} Min</Badge>
            <Badge tone="lossless">Lossless</Badge>
            <Badge tone="hires">Hi-Res 24-bit</Badge>
          </div>
          <div className="flex flex-wrap items-center gap-space-sm">
            <button onClick={onPlay} className="h-10 px-6 rounded-full bg-primary-container text-on-primary-container font-label-lg text-label-lg flex items-center gap-2 shadow-[0_4px_20px_rgba(224,131,110,0.35)] hover:scale-[1.02] active:scale-[0.98] transition-all" type="button">
              <Icon name="play_arrow" size={20} fill /> Play
            </button>
            <button onClick={onShuffle} className="h-10 px-5 rounded-full bg-white/[0.08] hover:bg-white/[0.14] text-on-surface font-label-lg text-label-lg flex items-center gap-2 backdrop-blur-md transition-colors" type="button">
              <Icon name="shuffle" size={18} /> Shuffle
            </button>
            <button onClick={onAdd} className="h-10 px-4 rounded-full bg-white/[0.08] hover:bg-white/[0.14] text-on-surface font-label-lg text-label-lg flex items-center gap-1.5 backdrop-blur-md transition-colors" type="button">
              <Icon name="add" size={18} /> Add
            </button>
            <button className="w-10 h-10 rounded-full bg-white/[0.08] hover:bg-white/[0.14] text-on-surface flex items-center justify-center backdrop-blur-md transition-colors" type="button">
              <Icon name="more_horiz" size={20} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
