import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Icon } from './ui';
import { getLyrics } from '../api';

// Session cache so the sidebar and the fullscreen player don't both fetch the
// same song (mirrors the backend: one lookup per song, ever).
const CACHE_TTL_MS = 30 * 60 * 1000;
const paneCache = new Map(); // songId -> { data, at }

const AUTOSCROLL_PAUSE_MS = 4000; // yield to the user after manual scroll

export default function LyricsPane({
  song,
  progress = 0,
  onSeekTo,
  variant = 'sidebar',
  className = '',
}) {
  const [state, setState] = useState({ status: 'idle', data: null });
  const scrollRef = useRef(null);
  const lineRefs = useRef([]);
  const lastUserScrollAt = useRef(0);
  const requestId = useRef(0);

  const songId = song?.id;

  const load = useCallback(async (force = false) => {
    if (!songId) return;
    if (!force) {
      const cached = paneCache.get(songId);
      if (cached && Date.now() - cached.at < CACHE_TTL_MS) {
        setState({ status: 'ready', data: cached.data });
        return;
      }
    }
    const request = ++requestId.current;
    setState({ status: 'loading', data: null });
    try {
      const data = await getLyrics(songId, force);
      if (request !== requestId.current) return;
      paneCache.set(songId, { data, at: Date.now() });
      setState({ status: 'ready', data });
    } catch {
      if (request !== requestId.current) return;
      setState({ status: 'error', data: null });
    }
  }, [songId]);

  useEffect(() => {
    lineRefs.current = [];
    if (scrollRef.current) scrollRef.current.scrollTop = 0;
    if (!songId) {
      setState({ status: 'idle', data: null });
      return;
    }
    load(false);
  }, [songId, load]);

  const lines = state.data?.lines || [];
  const synced = lines.length > 0;

  // Current line for the playback position (binary search over timestamps).
  const activeIndex = useMemo(() => {
    if (!lines.length) return -1;
    let low = 0;
    let high = lines.length - 1;
    let found = -1;
    while (low <= high) {
      const mid = (low + high) >> 1;
      if (lines[mid].time <= progress + 0.2) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }, [lines, progress]);

  // Follow the active line unless the listener is scrolling themselves.
  useEffect(() => {
    if (activeIndex < 0) return;
    const container = scrollRef.current;
    const line = lineRefs.current[activeIndex];
    if (!container || !line) return;
    if (Date.now() - lastUserScrollAt.current < AUTOSCROLL_PAUSE_MS) return;
    const containerBox = container.getBoundingClientRect();
    const lineBox = line.getBoundingClientRect();
    const delta = (lineBox.top + lineBox.height / 2) - (containerBox.top + container.clientHeight / 2);
    if (Math.abs(delta) < 10) return;
    container.scrollTo({ top: container.scrollTop + delta, behavior: 'smooth' });
  }, [activeIndex]);

  const markUserScroll = () => { lastUserScrollAt.current = Date.now(); };

  const isSidebar = variant === 'sidebar';
  const textSize = isSidebar ? 'font-body-md text-body-md' : 'font-headline-sm text-headline-sm';
  const pad = isSidebar ? 'px-1 py-3' : 'px-2 py-4';

  const header = (
    <div className="sticky top-0 z-10 flex items-center justify-between gap-space-xs pb-space-xs bg-surface-container-low/95 backdrop-blur-md">
      <div className="flex items-center gap-space-xs min-w-0">
        <Icon name="lyrics" size={16} className="text-primary shrink-0" />
        <span className="font-label-sm text-label-sm uppercase tracking-wider text-outline truncate">
          {state.data?.source === 'lrclib' ? 'Lyrics · LRCLIB' : 'Lyrics'}
        </span>
        {synced && (
          <span className="shrink-0 px-1.5 py-0.5 rounded bg-primary-container/20 text-primary font-label-sm text-label-sm">
            SYNCED
          </span>
        )}
      </div>
      <button
        onClick={() => load(true)}
        disabled={state.status === 'loading'}
        className="shrink-0 w-7 h-7 rounded-full flex items-center justify-center text-outline hover:text-on-surface hover:bg-surface-container-high transition-colors disabled:opacity-40"
        title="Re-fetch lyrics"
        type="button"
      >
        <Icon name="refresh" size={16} />
      </button>
    </div>
  );

  function renderBody() {
    if (!songId) {
      return <Hint icon="lyrics" title="Nothing playing" hint="Start a track to see its lyrics." />;
    }
    if (state.status === 'loading') {
      return (
        <div className="space-y-3 py-4 animate-pulse" aria-label="Loading lyrics">
          {[90, 70, 80, 55, 75].map((width, index) => (
            <div key={index} className="h-3 rounded bg-surface-container-highest" style={{ width: `${width}%` }} />
          ))}
        </div>
      );
    }
    if (state.status === 'error') {
      return (
        <Hint
          icon="error_outline"
          title="Couldn't load lyrics"
          hint="The lyrics service is unavailable right now."
          action={<RetryButton onClick={() => load(true)} />}
        />
      );
    }
    const data = state.data;
    if (!data) {
      return (
        <Hint
          icon="search_off"
          title="No lyrics found"
          hint={`We couldn't find lyrics for “${song?.title || 'this track'}”.`}
          action={<RetryButton onClick={() => load(true)} />}
        />
      );
    }
    if (data.instrumental) {
      return <Hint icon="graphic_eq" title="Instrumental track" hint="This song has no lyrics — enjoy the music." />;
    }
    if (synced) {
      return (
        <div className="space-y-0.5 py-2">
          {lines.map((line, index) => (
            <button
              key={`${line.time}-${index}`}
              ref={(el) => { lineRefs.current[index] = el; }}
              onClick={() => onSeekTo?.(line.time)}
              className={`block w-full text-left rounded-lg px-2 py-1.5 transition-colors ${
                index === activeIndex
                  ? 'text-primary bg-primary-container/10 font-semibold'
                  : 'text-on-surface-variant hover:text-on-surface hover:bg-surface-container-high'
              } ${onSeekTo ? 'cursor-pointer' : 'cursor-default'} ${textSize}`}
              title={onSeekTo ? 'Jump to this line' : undefined}
              type="button"
            >
              {line.text}
            </button>
          ))}
        </div>
      );
    }
    if (data.plain) {
      return (
        <div className={`whitespace-pre-line leading-relaxed text-on-surface-variant py-2 ${textSize}`}>
          {data.plain}
        </div>
      );
    }
    return (
      <Hint
        icon="search_off"
        title="No lyrics found"
        hint={`We couldn't find lyrics for “${song?.title || 'this track'}”.`}
        action={<RetryButton onClick={() => load(true)} />}
      />
    );
  }

  return (
    <div
      ref={scrollRef}
      onWheel={markUserScroll}
      onTouchMove={markUserScroll}
      onMouseDown={markUserScroll}
      className={`relative overflow-y-auto custom-scroll ${pad} ${className}`}
    >
      {header}
      {renderBody()}
    </div>
  );
}

function RetryButton({ onClick }) {
  return (
    <button
      onClick={onClick}
      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-surface-container-high hover:bg-surface-container-highest text-on-surface font-label-sm text-label-sm transition-colors"
      type="button"
    >
      <Icon name="refresh" size={14} />
      Try again
    </button>
  );
}

function Hint({ icon, title, hint, action }) {
  return (
    <div className="flex flex-col items-center text-center gap-2 py-8 px-2 animate-fade-up">
      <div className="w-12 h-12 rounded-2xl bg-surface-container flex items-center justify-center text-outline">
        <Icon name={icon} size={22} />
      </div>
      <p className="font-label-md text-label-md text-on-surface">{title}</p>
      <p className="font-body-sm text-body-sm text-outline">{hint}</p>
      {action}
    </div>
  );
}

