import React, { useState } from 'react';
import { Icon, Cover } from './ui';
import { fmtTime } from './ui';

export function Equalizer({ size = 'md' }) {
  return (
    <div className="flex items-end gap-[2px] h-3.5">
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="w-[2.5px] bg-primary eq-bar rounded-full"
          style={{ height: '100%', animationDelay: `${i * 0.2}s` }}
        />
      ))}
    </div>
  );
}

export default function QueueSidebar({ currentSong, queue = [], suggestions = [], onPlay, tab, setTab, isPlaying }) {
  return (
    <aside className="fixed right-0 top-0 bottom-0 w-80 bg-surface-container-low/80 backdrop-blur-xl z-30 flex flex-col p-space-md pb-28">
      <div className="flex items-center justify-between pb-space-md">
        <div className="flex items-center gap-space-xs">
          {['queue', 'lyrics', 'related'].map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-space-sm py-1 rounded-full font-label-sm text-label-sm transition-colors ${
                tab === t ? 'bg-surface-container-high text-on-surface' : 'text-outline hover:text-on-surface'
              }`}
              type="button"
            >
              {t === 'queue' ? 'Playing Next' : t === 'lyrics' ? 'Lyrics' : 'Related'}
            </button>
          ))}
        </div>
        <button className="w-7 h-7 flex items-center justify-center text-outline hover:text-on-surface transition-colors" type="button">
          <Icon name="clear_all" size={18} />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto space-y-space-md">
        {tab === 'queue' && (
          <>
            <div className="space-y-space-xs">
              <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline">Now Playing</span>
              {currentSong ? (
                <div className="p-space-sm rounded-xl bg-surface-container flex items-center gap-space-sm">
                  <Cover src={currentSong.cover_art || currentSong.thumbnail} size="w-12 h-12" rounded="rounded-lg" icon="album" />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-space-xs">
                      <span className="font-label-md text-label-md text-primary truncate">{currentSong.title || 'Unknown'}</span>
                      <span className="px-1 rounded bg-surface-container-highest font-label-sm text-label-sm text-outline">Hi-Res</span>
                    </div>
                    <span className="font-body-sm text-body-sm text-on-surface-variant truncate block">{currentSong.artist || 'Unknown Artist'}</span>
                  </div>
                  {isPlaying ? <Equalizer /> : <Icon name="equalizer" size={18} className="text-primary" />}
                </div>
              ) : (
                <p className="font-body-sm text-body-sm text-outline px-1">Nothing playing yet.</p>
              )}
            </div>

            <div className="space-y-space-xs">
              <div className="flex items-center justify-between">
                <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline">Next in Queue</span>
                <span className="font-label-sm text-label-sm text-primary cursor-pointer hover:underline">Shuffle All</span>
              </div>
              <div className="space-y-1">
                {queue.slice(0, 8).map((s, i) => (
                  <div key={s.id ?? i} onClick={() => onPlay(s)} className="flex items-center gap-space-sm p-space-xs rounded-lg hover:bg-surface-container-high transition-colors group cursor-pointer">
                    <span className="font-label-sm text-label-sm text-outline w-4 text-center group-hover:hidden">{i + 1}</span>
                    <button className="hidden group-hover:flex w-4 items-center justify-center text-on-surface" type="button">
                      <Icon name="play_arrow" size={16} />
                    </button>
                    <Cover src={s.cover_art || s.thumbnail} size="w-9 h-9" />
                    <div className="flex-1 min-w-0">
                      <span className="font-label-md text-label-md text-on-surface truncate block">{s.title}</span>
                      <span className="font-body-sm text-body-sm text-on-surface-variant truncate block">{s.artist}</span>
                    </div>
                    <span className="font-body-sm text-body-sm text-outline">{fmtTime(s.duration)}</span>
                  </div>
                ))}
                {queue.length === 0 && <p className="font-body-sm text-body-sm text-outline px-1">Queue is empty.</p>}
              </div>
            </div>

            {suggestions.length > 0 && (
              <div className="space-y-space-xs pt-space-xs">
                <div className="flex items-center justify-between">
                  <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline">AutoPlay Suggestions</span>
                  <Icon name="all_inclusive" size={16} className="text-outline" />
                </div>
                {suggestions.slice(0, 3).map((s) => (
                  <div key={s.id} onClick={() => onPlay(s)} className="flex items-center gap-space-sm p-space-xs rounded-lg bg-surface-container-highest/20 hover:bg-surface-container-high transition-colors cursor-pointer">
                    <Cover src={s.cover_art} size="w-9 h-9" icon="smart_toy" />
                    <div className="flex-1 min-w-0">
                      <span className="font-label-md text-label-md text-on-surface truncate block">{s.title}</span>
                      <span className="font-body-sm text-body-sm text-on-surface-variant truncate block">{s.artist}</span>
                    </div>
                    <button className="text-outline hover:text-on-surface" type="button" onClick={(e) => e.stopPropagation()}>
                      <Icon name="add" size={18} />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </>
        )}

        {tab === 'lyrics' && (
          <div className="p-space-md rounded-xl bg-surface-container">
            <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline block mb-2">Lyrics</span>
            <p className="font-body-md text-body-md text-on-surface-variant leading-relaxed">Lyrics aren&apos;t available for this track yet. Enjoy the lossless stream.</p>
          </div>
        )}

        {tab === 'related' && (
          <div className="space-y-1">
            <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline">Related</span>
            {suggestions.map((s) => (
              <div key={s.id} onClick={() => onPlay(s)} className="flex items-center gap-space-sm p-space-xs rounded-lg hover:bg-surface-container-high transition-colors cursor-pointer">
                <Cover src={s.cover_art} size="w-9 h-9" />
                <div className="flex-1 min-w-0">
                  <span className="font-label-md text-label-md text-on-surface truncate block">{s.title}</span>
                  <span className="font-body-sm text-body-sm text-on-surface-variant truncate block">{s.artist}</span>
                </div>
              </div>
            ))}
            {suggestions.length === 0 && <p className="font-body-sm text-body-sm text-outline">Play something to get recommendations.</p>}
          </div>
        )}
      </div>
    </aside>
  );
}
