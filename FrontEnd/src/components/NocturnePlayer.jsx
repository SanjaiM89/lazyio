import React, { useEffect, useRef, useState } from 'react';
import { Icon, Cover } from './ui';
import { getVideoStreamUrl } from '../api';
import LyricsPane from './LyricsPane';

const fmtClock = (s) => {
  if (s == null || isNaN(s)) return '0:00';
  return `${Math.floor(s / 60)}:${Math.floor(s % 60).toString().padStart(2, '0')}`;
};

const fmtLeft = (progress, duration) => {
  const left = Math.max(0, (duration || 0) - (progress || 0));
  return `-${Math.floor(left / 60)}:${Math.floor(left % 60).toString().padStart(2, '0')}`;
};

export default function NocturnePlayer({
  song, isPlaying, progress, duration, volume, setVolume,
  onToggle, onNext, onPrev, onSeek, onSeekTo, onClose,
  queue = [], onPlay, suggestions = [],
  shuffle, setShuffle, repeat, setRepeat, onAdd,
  autoplay = true, setAutoplay,
  hasVideo, mode, setMode, videoRef, audioRef,
}) {
  const [tab, setTab] = useState('queue');
  const [loved, setLoved] = useState(false);
  const wasAudioPlaying = useRef(false);
  const inVideo = mode === 'video' && hasVideo;

  // Seconds-based seek for the lyrics pane (tap a line to jump to it).
  const seekToSeconds = (t) => {
    if (typeof onSeekTo === 'function') onSeekTo(t);
    else if (typeof onSeek === 'function') onSeek({ target: { value: t } });
  };

  // Entering video mode pauses shared audio; leaving restores position.
  useEffect(() => {
    if (inVideo) {
      wasAudioPlaying.current = isPlaying;
      try { audioRef?.current?.pause(); } catch { /* noop */ }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [inVideo]);

  if (!song) return null;
  const pct = duration > 0 ? (progress / duration) * 100 : 0;
  const totalSec = queue.reduce((a, s) => a + (s.duration || 0), 0);

  const exitVideo = () => {
    const v = videoRef?.current;
    const a = audioRef?.current;
    if (v && a) {
      try {
        if (!v.paused) {
          a.currentTime = v.currentTime || 0;
          a.play().catch(() => {});
        }
        v.pause();
      } catch { /* noop */ }
    }
    setMode?.('audio');
  };

  const handleMinimize = () => {
    if (inVideo) exitVideo();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 bg-background text-on-surface flex flex-col select-none overflow-hidden">
      {/* Ambient backdrop — same wash as the album hero */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-32 left-1/4 w-[750px] h-[480px] bg-secondary-container/40 blur-[130px] rounded-full mix-blend-screen" />
        <div className="absolute top-1/3 right-10 w-[420px] h-[360px] bg-primary-container/15 blur-[100px] rounded-full" />
        <div className="absolute -bottom-40 left-1/4 w-[700px] h-[420px] bg-secondary-container/25 blur-[130px] rounded-full" />
      </div>

      {/* Top bar */}
      <header className="relative z-20 shrink-0 flex items-center justify-between px-margin py-4 border-b border-white/[0.06] bg-surface/80 backdrop-blur-xl">
        <div className="flex items-center gap-space-sm">
          <button
            onClick={handleMinimize}
            className="group flex items-center gap-2 px-3 py-1.5 rounded-full bg-surface-container-high hover:bg-surface-container-highest transition-colors"
            title="Minimize to mini-player"
            type="button"
          >
            <Icon name="expand_more" size={18} className="text-on-surface-variant group-hover:text-on-surface transition-colors" />
            <span className="font-label-md text-label-md text-on-surface-variant group-hover:text-on-surface">Now Playing</span>
          </button>
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-secondary-container/30 border border-white/[0.06] font-label-sm text-label-sm text-secondary">
            <span className="w-1.5 h-1.5 rounded-full bg-secondary animate-pulse" />
            Hi-Res Lossless
          </span>
        </div>
        <div className="hidden md:flex items-center gap-space-xs px-4 py-1.5 rounded-full bg-surface-container-low border border-white/[0.06] font-body-sm text-body-sm">
          <Icon name="graphic_eq" size={14} className="text-primary" />
          <span className="text-on-surface-variant font-medium">Lazyio Hi-Fi</span>
          <span className="w-1 h-1 rounded-full bg-outline" />
          <span className="text-primary font-semibold">Bit-Perfect</span>
        </div>
        <div className="flex items-center gap-space-xs">
          <span className="hidden sm:inline-flex items-center px-2 py-0.5 rounded bg-surface-container-highest/60 text-primary font-label-sm text-label-sm font-bold tracking-widest">
            LOSSLESS
          </span>
          {hasVideo && (
            <div className="flex bg-surface-container-high rounded-full p-0.5">
              {['audio', 'video'].map((m) => (
                <button
                  key={m}
                  onClick={() => (m === 'video' ? setMode('video') : exitVideo())}
                  className={`px-3 py-1 rounded-full font-label-sm text-label-sm capitalize transition-all ${(!inVideo && m === 'audio') || (inVideo && m === 'video') ? 'bg-primary-container text-on-primary-container font-semibold' : 'text-outline hover:text-on-surface'}`}
                  type="button"
                >
                  {m}
                </button>
              ))}
            </div>
          )}
          <button onClick={() => setTab('lyrics')} className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${tab === 'lyrics' ? 'text-primary bg-surface-container-high' : 'text-outline hover:text-on-surface hover:bg-surface-container-high'}`} title="View Lyrics" type="button">
            <Icon name="lyrics" size={18} />
          </button>
          <button onClick={handleMinimize} className="w-8 h-8 rounded-full flex items-center justify-center text-outline hover:text-on-surface hover:bg-surface-container-high transition-colors" title="Exit Fullscreen" type="button">
            <Icon name="fullscreen_exit" size={18} />
          </button>
        </div>
      </header>

      {/* Main stage — fits the viewport; columns scroll internally */}
      <main className="relative z-10 flex-1 min-h-0 grid grid-cols-12 gap-space-md px-margin py-space-md lg:overflow-hidden overflow-y-auto">
        <section className="col-span-12 lg:col-span-8 flex flex-col lg:min-h-0 lg:overflow-hidden">
          <div className="flex-1 w-full min-h-0 lg:overflow-y-auto custom-scroll flex flex-col">
          <div className="m-auto w-full flex flex-col items-center py-space-sm">
            {inVideo ? (
              <div className="w-full max-w-2xl aspect-video max-h-[46vh] rounded-2xl overflow-hidden bg-black shadow-[0_24px_50px_rgba(0,0,0,0.7)] border border-white/[0.08] shrink-0">
                <video
                  key={song.id}
                  ref={videoRef}
                  src={getVideoStreamUrl(song.id)}
                  className="w-full h-full object-contain"
                  controls
                  autoPlay={wasAudioPlaying.current}
                  playsInline
                />
              </div>
            ) : (
              <div className="relative group cursor-pointer">
                <div className="absolute -inset-10 bg-secondary-container/30 blur-3xl rounded-full opacity-75 group-hover:opacity-100 transition-opacity duration-700" />
                <div
                  className={`relative rounded-full vinyl-grooves p-3.5 flex items-center justify-center animate-spin-slow border border-white/[0.07] shrink-0 ${isPlaying ? '' : 'vinyl-paused'}`}
                  style={{ width: 'max(200px, min(40vh, 380px))', height: 'max(200px, min(40vh, 380px))', fontSize: 'calc(max(200px, min(40vh, 380px)) / 19)' }}
                >
                  <div className="absolute inset-0 rounded-full vinyl-sheen pointer-events-none" />
                  <div className="w-full h-full rounded-full border border-white/[0.04] flex items-center justify-center p-[2.4em]">
                    <div className="w-full h-full rounded-full border border-white/[0.05] flex items-center justify-center p-[2em]">
                      <div className="relative w-[7.2em] h-[7.2em] rounded-full overflow-hidden border-2 border-primary-container/60 bg-surface-container flex flex-col items-center justify-center text-center p-2 shrink-0">
                        {(song.cover_art || song.thumbnail) && (
                          <img src={song.cover_art || song.thumbnail} alt="" className="absolute inset-0 w-full h-full object-cover" />
                        )}
                        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent" />
                        <span className="relative font-label-sm text-label-sm uppercase tracking-widest text-primary truncate max-w-full px-2">{song.album || 'Lazyio'}</span>
                        <h4 className="relative font-label-lg text-label-lg text-on-surface truncate max-w-full px-2">{song.title}</h4>
                        <p className="relative font-body-sm text-body-sm text-on-surface-variant truncate max-w-full px-2">{song.artist}</p>
                        <div className="relative w-5 h-5 mt-2 rounded-full bg-surface-container-lowest border-2 border-surface-container-highest flex items-center justify-center">
                          <div className="w-1.5 h-1.5 rounded-full bg-black" />
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <div className="absolute -top-3 -right-2 bg-surface-container-low/80 backdrop-blur-md px-2.5 py-1 rounded-full border border-white/[0.08] font-body-sm text-body-sm text-on-surface-variant flex items-center gap-1.5">
                  <span className={`w-2 h-2 rounded-full ${isPlaying ? 'bg-primary animate-pulse' : 'bg-outline'}`} />
                  {isPlaying ? 'Playing' : 'Paused'}
                </div>
              </div>
            )}

            <div className="text-center mt-space-md max-w-xl">
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight truncate">{song.title || 'Unknown Title'}</h1>
              <div className="flex items-center justify-center gap-space-xs mt-1 mb-2">
                <span className="font-label-lg text-label-lg text-on-surface-variant truncate">{song.artist || 'Unknown Artist'}</span>
                <Icon name="check_circle" size={18} className="text-primary icon-fill shrink-0" fill />
              </div>
              <p className="font-body-sm text-body-sm text-outline uppercase tracking-wider truncate">
                {song.album || 'Single'} <span className="mx-1">•</span> {song.year || ''} {song.year ? <span className="mx-1">•</span> : null} Lossless
              </p>
              <div className="flex items-center justify-center gap-space-sm mt-space-sm">
                <button onClick={() => setLoved(!loved)} className={`w-10 h-10 rounded-full flex items-center justify-center backdrop-blur-md transition-colors ${loved ? 'bg-primary-container text-on-primary-container' : 'bg-white/[0.08] hover:bg-white/[0.14] text-on-surface'}`} title="Add to Favorites" type="button">
                  <Icon name="favorite" size={18} fill={loved} className={loved ? '' : 'text-tertiary'} />
                </button>
                <button onClick={() => onAdd?.(song)} className="h-10 px-4 rounded-full bg-white/[0.08] hover:bg-white/[0.14] text-on-surface font-label-lg text-label-lg flex items-center gap-1.5 backdrop-blur-md transition-colors" title="Add to Playlist" type="button">
                  <Icon name="add" size={18} /> Add
                </button>
                <button onClick={() => onAdd?.(song)} className="w-10 h-10 rounded-full bg-white/[0.08] hover:bg-white/[0.14] text-on-surface flex items-center justify-center backdrop-blur-md transition-colors" title="More Track Options" type="button">
                  <Icon name="more_horiz" size={20} />
                </button>
              </div>
            </div>
          </div>
          </div>

          {/* Transport deck — pinned, never scrolls away */}
          <div className="w-full max-w-3xl mx-auto pb-space-sm shrink-0">
            <div className="flex items-center gap-space-sm font-mono text-xs text-outline select-none">
              <span className="w-10 text-right">{fmtClock(progress)}</span>
              <div className="relative flex-1 group py-3 cursor-pointer">
                <div className="h-1.5 w-full rounded-full bg-surface-container-highest overflow-hidden">
                  <div className="h-full bg-primary rounded-full" style={{ width: `${pct}%` }} />
                </div>
                <div className="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-3.5 h-3.5 rounded-full bg-primary ring-2 ring-background scale-90 group-hover:scale-110 transition-transform pointer-events-none" style={{ left: `${pct}%` }} />
                <input type="range" min="0" max={duration || 100} value={progress} onChange={onSeek} className="absolute inset-0 w-full opacity-0 cursor-pointer" />
              </div>
              <span className="w-12">{fmtLeft(progress, duration)}</span>
            </div>
            <div className="flex items-center justify-between mt-2 px-2 sm:px-6">
              <div className="flex items-center gap-space-xs">
                <button onClick={() => setShuffle?.(!shuffle)} className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${shuffle ? 'text-primary' : 'text-outline hover:text-on-surface hover:bg-surface-container-high'}`} title="Toggle Shuffle" type="button">
                  <Icon name="shuffle" size={18} />
                </button>
                <span className="hidden sm:flex items-center gap-1 font-body-sm text-body-sm text-on-surface-variant">
                  <Icon name="equalizer" size={16} className="text-primary" />
                  Lossless EQ
                </span>
              </div>
              <div className="flex items-center gap-space-md">
                <button onClick={onPrev} className="text-on-surface hover:text-primary transition-colors" title="Previous Track" type="button">
                  <Icon name="skip_previous" size={28} fill />
                </button>
                <button onClick={onToggle} className="w-14 h-14 rounded-full bg-primary flex items-center justify-center text-on-primary hover:bg-primary-fixed hover:scale-105 active:scale-95 shadow-[0_4px_20px_rgba(224,131,110,0.35)] transition-all" title={isPlaying ? 'Pause Track' : 'Play Track'} type="button">
                  <Icon name={isPlaying ? 'pause' : 'play_arrow'} size={30} fill />
                </button>
                <button onClick={onNext} className="text-on-surface hover:text-primary transition-colors" title="Next Track" type="button">
                  <Icon name="skip_next" size={28} fill />
                </button>
              </div>
              <div className="flex items-center gap-space-xs">
                <button onClick={() => setRepeat?.(!repeat)} className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors relative ${repeat ? 'text-primary' : 'text-outline hover:text-on-surface hover:bg-surface-container-high'}`} title="Repeat" type="button">
                  <Icon name="repeat" size={18} />
                </button>
                <div className="hidden sm:flex items-center gap-space-xs w-28">
                  <button className="text-outline hover:text-on-surface transition-colors" title="Mute Volume" type="button" onClick={() => setVolume(volume > 0 ? 0 : 0.8)}>
                    <Icon name={volume === 0 ? 'volume_off' : 'volume_up'} size={18} />
                  </button>
                  <div className="flex-1 h-1 bg-surface-container-highest rounded-full overflow-hidden cursor-pointer relative">
                    <div className="h-full bg-on-surface-variant rounded-full" style={{ width: `${volume * 100}%` }} />
                    <input type="range" min="0" max="1" step="0.01" value={volume} onChange={(e) => setVolume(parseFloat(e.target.value))} className="absolute inset-0 w-full opacity-0 cursor-pointer" />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Up Next drawer */}
        <aside className="col-span-12 lg:col-span-4 flex flex-col lg:min-h-0">
          <div className="flex-1 rounded-2xl bg-surface-container-low/80 backdrop-blur-xl border border-white/[0.06] flex flex-col overflow-hidden min-h-[420px] lg:min-h-0">
            <div className="flex items-center justify-between px-space-md pt-space-md pb-space-sm border-b border-white/[0.06]">
              <div className="flex items-center gap-space-xs">
                {['queue', 'lyrics', 'related'].map((t) => (
                  <button
                    key={t}
                    onClick={() => setTab(t)}
                    className={`px-space-sm py-1 rounded-full font-label-sm text-label-sm transition-colors ${tab === t ? 'bg-surface-container-high text-on-surface' : 'text-outline hover:text-on-surface'}`}
                    type="button"
                  >
                    {t === 'queue' ? 'Playing Next' : t === 'lyrics' ? 'Lyrics' : 'Related'}
                  </button>
                ))}
              </div>
              <div className="flex items-center gap-1 font-body-sm text-body-sm text-outline bg-surface-container-high px-2.5 py-1 rounded-md">
                <span>{queue.length} tracks</span>
                <span className="text-outline/50">•</span>
                <span>{Math.floor(totalSec / 60)}m</span>
              </div>
            </div>

            <div className="flex-1 min-h-0 overflow-y-auto custom-scroll p-space-sm space-y-1 max-h-[60vh] lg:max-h-none">
              {tab === 'lyrics' && (
                <LyricsPane
                  song={song}
                  progress={progress}
                  onSeekTo={seekToSeconds}
                  variant="full"
                  className="h-full min-h-[320px]"
                />
              )}
              {tab === 'related' && (
                suggestions.length === 0 ? (
                  <p className="p-4 text-center font-body-sm text-body-sm text-outline">Play more to get recommendations.</p>
                ) : suggestions.map((s) => (
                  <QueueRow key={s.id} s={s} onPlay={onPlay} active={song.id === s.id} />
                ))
              )}
              {tab === 'queue' && (
                queue.length === 0 ? (
                  <p className="p-4 text-center font-body-sm text-body-sm text-outline">Queue is empty.</p>
                ) : queue.map((s, i) => (
                  <QueueRow key={s.id ?? i} s={s} onPlay={onPlay} active={song.id === s.id} next={i === 0} index={i} />
                ))
              )}
            </div>

            <div className="p-space-sm bg-surface-container-low border-t border-white/[0.06] flex items-center justify-between">
              <div className="flex items-center gap-space-sm">
                <Icon name="all_inclusive" size={18} className="text-primary" />
                <div>
                  <span className="font-label-md text-label-md text-on-surface block">Infinite Autoplay</span>
                  <span className="font-body-sm text-body-sm text-outline">Similar songs will follow</span>
                </div>
              </div>
              <button onClick={() => setAutoplay?.(!autoplay)} className={`w-9 h-5 rounded-full p-0.5 flex transition-colors ${autoplay ? 'bg-primary-container justify-end' : 'bg-surface-container-highest justify-start'}`} type="button" title="Toggle Autoplay">
                <div className="w-4 h-4 rounded-full bg-white shadow-md" />
              </button>
            </div>
          </div>
        </aside>
      </main>
    </div>
  );
}

function QueueRow({ s, onPlay, active, next, index }) {
  return (
    <div
      onClick={() => onPlay(s)}
      className={`group flex items-center justify-between p-space-xs rounded-lg transition-colors cursor-pointer ${active || next ? 'bg-surface-container border border-primary-container/30' : 'border border-transparent hover:bg-surface-container-high'}`}
    >
      <div className="flex items-center gap-space-sm min-w-0">
        <Cover src={s.cover_art || s.thumbnail} size="w-11 h-11" rounded="rounded-lg" icon="music_note" />
        <div className="truncate">
          <div className="flex items-center gap-space-xs">
            <h5 className={`font-label-md text-label-md truncate ${active ? 'text-primary' : 'text-on-surface'}`}>{s.title}</h5>
            {next && <span className="font-label-sm text-label-sm text-primary bg-primary-container/20 px-1.5 py-0.5 rounded shrink-0">NEXT</span>}
          </div>
          <p className="font-body-sm text-body-sm text-on-surface-variant truncate">{s.artist}</p>
        </div>
      </div>
      <div className="flex items-center gap-space-sm shrink-0">
        <span className="font-body-sm text-body-sm text-outline font-mono">{fmtClock(s.duration)}</span>
        <span className="opacity-0 group-hover:opacity-100 text-outline hover:text-on-surface transition-opacity">
          <Icon name="more_horiz" size={18} />
        </span>
      </div>
    </div>
  );
}
