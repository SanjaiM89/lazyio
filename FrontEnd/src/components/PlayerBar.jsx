import React from 'react';
import { Icon, Cover, SongBadges, fmtTime } from './ui';

export default function PlayerBar({
  currentSong, isPlaying, progress, duration, volume, setVolume,
  onToggle, onNext, onPrev, onSeek, onExpand, shuffle, setShuffle, repeat, setRepeat,
}) {
  const pct = duration > 0 ? (progress / duration) * 100 : 0;
  return (
    <div className="fixed bottom-3 left-64 right-80 px-space-md z-40 pointer-events-none">
      <div className="pointer-events-auto h-20 rounded-2xl bg-surface-container-high/90 backdrop-blur-2xl border border-white/[0.08] shadow-[0_20px_48px_rgba(0,0,0,0.55)] px-space-md flex items-center justify-between gap-space-md">
        <div className="flex items-center gap-space-sm w-1/4 min-w-[200px] cursor-pointer" onClick={onExpand}>
          <Cover src={currentSong?.cover_art} size="w-12 h-12" rounded="rounded-xl" icon="album" />
          <div className="flex flex-col min-w-0">
            <div className="flex items-center gap-space-xs">
              <span className="font-label-md text-label-md text-on-surface truncate">{currentSong?.title || 'Nothing playing'}</span>
              {currentSong && <span className="px-1.5 py-0.5 rounded bg-surface-container font-label-sm text-label-sm text-primary border border-white/[0.08]">LOSSLESS</span>}
            </div>
            <span className="font-body-sm text-body-sm text-on-surface-variant truncate">{currentSong?.artist || 'Pick a track'}</span>
            <SongBadges song={currentSong} compact className="mt-0.5" />
          </div>
          <button className="text-outline hover:text-tertiary transition-colors ml-space-xs" type="button" onClick={(e) => e.stopPropagation()}>
            <Icon name="favorite" size={20} />
          </button>
        </div>

        <div className="flex flex-col items-center gap-1.5 flex-1 max-w-xl">
          <div className="flex items-center gap-space-md">
            <button onClick={() => setShuffle(!shuffle)} className={`${shuffle ? 'text-primary' : 'text-outline'} hover:text-on-surface transition-colors`} type="button">
              <Icon name="shuffle" size={18} />
            </button>
            <button onClick={onPrev} className="text-on-surface hover:text-primary transition-colors" type="button">
              <Icon name="skip_previous" size={22} fill />
            </button>
            <button onClick={onToggle} className="w-9 h-9 rounded-full bg-primary flex items-center justify-center text-on-primary hover:bg-primary-fixed transition-all" type="button">
              <Icon name={isPlaying ? 'pause' : 'play_arrow'} size={22} fill />
            </button>
            <button onClick={onNext} className="text-on-surface hover:text-primary transition-colors" type="button">
              <Icon name="skip_next" size={22} fill />
            </button>
            <button onClick={() => setRepeat(!repeat)} className={`${repeat ? 'text-primary' : 'text-outline'} hover:text-on-surface transition-colors`} type="button">
              <Icon name="repeat" size={18} />
            </button>
          </div>
          <div className="w-full flex items-center gap-space-sm">
            <span className="font-label-sm text-label-sm text-outline w-8 text-right">{fmtTime(progress)}</span>
            <div className="flex-1 h-1 bg-surface-container-highest rounded-full overflow-hidden relative cursor-pointer group">
              <div className="h-full bg-primary rounded-full relative group-hover:bg-primary-fixed" style={{ width: `${pct}%` }}>
                <div className="absolute right-0 top-1/2 -translate-y-1/2 w-2.5 h-2.5 bg-on-primary rounded-full ring-2 ring-primary opacity-0 group-hover:opacity-100 transition-opacity" />
              </div>
              <input type="range" min="0" max={duration || 100} value={progress} onChange={onSeek} className="absolute inset-0 w-full opacity-0 cursor-pointer" />
            </div>
            <span className="font-label-sm text-label-sm text-outline w-8">{fmtTime(duration)}</span>
          </div>
        </div>

        <div className="flex items-center justify-end gap-space-sm w-1/4 min-w-[200px]">
          <button className="text-outline hover:text-on-surface transition-colors" type="button"><Icon name="lyrics" size={18} /></button>
          <button className="text-outline hover:text-on-surface transition-colors" type="button"><Icon name="picture_in_picture_alt" size={18} /></button>
          <div className="flex items-center gap-space-xs w-28">
            <button className="text-outline hover:text-on-surface transition-colors" type="button"><Icon name="volume_up" size={18} /></button>
            <div className="flex-1 h-1 bg-surface-container-highest rounded-full overflow-hidden cursor-pointer relative">
              <div className="h-full bg-on-surface-variant rounded-full" style={{ width: `${volume * 100}%` }} />
              <input type="range" min="0" max="1" step="0.01" value={volume} onChange={(e) => setVolume(parseFloat(e.target.value))} className="absolute inset-0 w-full opacity-0 cursor-pointer" />
            </div>
          </div>
          <button className="text-primary hover:text-primary-fixed transition-colors" type="button"><Icon name="queue_music" size={20} /></button>
        </div>
      </div>
    </div>
  );
}
