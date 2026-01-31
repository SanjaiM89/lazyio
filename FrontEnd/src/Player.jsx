import React, { useState, useRef, useEffect } from 'react';
import { getStreamUrl, getVideoStreamUrl } from './api';

const Player = ({ currentSong, onNext, onPrev, playlist = [], onSelectSong, miniBar = false, fullView = false }) => {
    const audioRef = useRef(null);
    const videoRef = useRef(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [progress, setProgress] = useState(0);
    const [duration, setDuration] = useState(0);
    const [volume, setVolume] = useState(0.8);
    const [showVolume, setShowVolume] = useState(false);

    // Unified player: 'audio' or 'video' mode
    const [mode, setMode] = useState('audio');
    const [videoLoading, setVideoLoading] = useState(false);
    const [videoError, setVideoError] = useState(null);

    // Check if current song has video
    const hasVideo = currentSong?.hasVideo || currentSong?.has_video;

    useEffect(() => {
        if (currentSong && audioRef.current) {
            // Reset to audio mode when song changes
            setMode('audio');
            setVideoError(null);
            audioRef.current.play().catch(e => console.error("Play error:", e));
            setIsPlaying(true);
        }
    }, [currentSong]);

    useEffect(() => {
        if (audioRef.current) {
            audioRef.current.volume = volume;
        }
        if (videoRef.current) {
            videoRef.current.volume = volume;
        }
    }, [volume]);

    // Sync video with mode changes
    useEffect(() => {
        if (mode === 'video' && currentSong && hasVideo) {
            setVideoLoading(true);
            setVideoError(null);
            // Video will auto-load, we handle events
        }
    }, [mode, currentSong, hasVideo]);

    const togglePlay = () => {
        const media = mode === 'video' ? videoRef.current : audioRef.current;
        if (media) {
            if (isPlaying) {
                media.pause();
            } else {
                media.play();
            }
            setIsPlaying(!isPlaying);
        }
    };

    const handleTimeUpdate = () => {
        const media = mode === 'video' ? videoRef.current : audioRef.current;
        if (media) {
            setProgress(media.currentTime);
            setDuration(media.duration || 0);
        }
    };

    const handleSeek = (e) => {
        const time = parseFloat(e.target.value);
        const media = mode === 'video' ? videoRef.current : audioRef.current;
        if (media) {
            media.currentTime = time;
            setProgress(time);
        }
    };

    const formatTime = (seconds) => {
        if (!seconds || isNaN(seconds)) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? '0' : ''}${s}`;
    };

    // Switch between audio and video modes
    const switchMode = (newMode) => {
        if (newMode === mode) return;

        const currentTime = mode === 'video'
            ? videoRef.current?.currentTime || 0
            : audioRef.current?.currentTime || 0;

        if (newMode === 'video') {
            // Pause audio, switch to video
            if (audioRef.current) {
                audioRef.current.pause();
            }
            setMode('video');
            // Video element will seek after loading
            setTimeout(() => {
                if (videoRef.current) {
                    videoRef.current.currentTime = currentTime;
                    videoRef.current.play().catch(e => console.error("Video play error:", e));
                    setIsPlaying(true);
                }
            }, 100);
        } else {
            // Pause video, switch to audio
            if (videoRef.current) {
                videoRef.current.pause();
            }
            setMode('audio');
            // Resume audio at saved position
            setTimeout(() => {
                if (audioRef.current) {
                    audioRef.current.currentTime = currentTime;
                    audioRef.current.play().catch(e => console.error("Audio play error:", e));
                    setIsPlaying(true);
                }
            }, 100);
        }
    };

    const handleVideoLoaded = () => {
        setVideoLoading(false);
        if (videoRef.current && isPlaying) {
            videoRef.current.play().catch(e => console.error("Video play error:", e));
        }
    };

    const handleVideoError = (e) => {
        console.error("Video error:", e);
        setVideoLoading(false);
        setVideoError("Video unavailable. Try audio mode.");
    };

    const progressPercent = duration > 0 ? (progress / duration) * 100 : 0;

    // Song/Video Toggle Component
    const ModeToggle = ({ className = "" }) => {
        if (!hasVideo) return null;
        return (
            <div className={`flex bg-white/10 rounded-full p-1 ${className}`}>
                <button
                    onClick={() => switchMode('audio')}
                    className={`px-4 py-1.5 rounded-full text-sm font-medium transition-all ${mode === 'audio'
                            ? 'bg-white text-black'
                            : 'text-white/70 hover:text-white'
                        }`}
                >
                    Song
                </button>
                <button
                    onClick={() => switchMode('video')}
                    className={`px-4 py-1.5 rounded-full text-sm font-medium transition-all ${mode === 'video'
                            ? 'bg-white text-black'
                            : 'text-white/70 hover:text-white'
                        }`}
                >
                    Video
                </button>
            </div>
        );
    };

    // Mini bar mode - just the bottom player controls
    if (miniBar) {
        return (
            <>
                {/* Bottom Player Bar */}
                <div className="h-24 glass border-t border-white/10 flex items-center px-6 gap-6">
                    {/* Left - Song Info */}
                    <div className="flex items-center gap-4 w-64 flex-shrink-0">
                        {currentSong ? (
                            <>
                                <div className={`w-14 h-14 rounded-lg bg-gradient-to-br from-pink-500/30 to-purple-600/30 flex items-center justify-center overflow-hidden ${isPlaying ? 'animate-spin-slow' : ''}`}>
                                    {currentSong.cover_art || currentSong.thumbnail ? (
                                        <img src={currentSong.cover_art || currentSong.thumbnail} alt="" className="w-full h-full object-cover" />
                                    ) : (
                                        <svg className="w-7 h-7 text-white/60" fill="currentColor" viewBox="0 0 24 24">
                                            <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                                        </svg>
                                    )}
                                </div>
                                <div className="flex-1 min-w-0">
                                    <p className="font-semibold truncate text-sm">{currentSong.title}</p>
                                    <p className="text-xs text-white/50 truncate">{currentSong.artist}</p>
                                </div>
                            </>
                        ) : (
                            <div className="text-white/30 text-sm">No song selected</div>
                        )}
                    </div>

                    {/* Center - Progress Bar */}
                    <div className="flex-1 flex items-center gap-3">
                        <span className="text-xs text-white/40 w-10 text-right">{formatTime(progress)}</span>
                        <div className="flex-1 relative h-1 bg-white/10 rounded-full overflow-hidden">
                            <div
                                className="absolute left-0 top-0 h-full bg-gradient-to-r from-pink-500 to-pink-400 rounded-full transition-all"
                                style={{ width: `${progressPercent}%` }}
                            />
                            <input
                                type="range"
                                min="0"
                                max={duration || 100}
                                value={progress}
                                onChange={handleSeek}
                                className="absolute inset-0 w-full opacity-0 cursor-pointer"
                            />
                        </div>
                        <span className="text-xs text-white/40 w-10">{formatTime(duration)}</span>
                    </div>

                    {/* Right - Controls & Volume */}
                    <div className="flex items-center gap-4 flex-shrink-0">
                        <button onClick={onPrev} className="control-btn control-btn-secondary w-10 h-10">
                            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M6 6h2v12H6V6zm3.5 6 8.5 6V6l-8.5 6z" />
                            </svg>
                        </button>
                        <button
                            onClick={togglePlay}
                            className="control-btn control-btn-primary w-12 h-12"
                            disabled={!currentSong}
                        >
                            {isPlaying ? (
                                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                                    <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" />
                                </svg>
                            ) : (
                                <svg className="w-5 h-5 ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                                    <path d="M8 5v14l11-7z" />
                                </svg>
                            )}
                        </button>
                        <button onClick={onNext} className="control-btn control-btn-secondary w-10 h-10">
                            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M6 18l8.5-6L6 6v12zm2 0h2V6h-2v12z" transform="scale(-1, 1) translate(-24, 0)" />
                            </svg>
                        </button>

                        {/* Volume */}
                        <div className="flex items-center gap-2 ml-4">
                            <button
                                className="text-white/40 hover:text-white transition"
                                onClick={() => setVolume(volume > 0 ? 0 : 0.8)}
                            >
                                {volume === 0 ? (
                                    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                                        <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" />
                                    </svg>
                                ) : (
                                    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                                        <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" />
                                    </svg>
                                )}
                            </button>
                            <input
                                type="range"
                                min="0"
                                max="1"
                                step="0.01"
                                value={volume}
                                onChange={(e) => setVolume(parseFloat(e.target.value))}
                                className="w-20"
                            />
                        </div>
                    </div>
                </div>
                <audio
                    ref={audioRef}
                    src={currentSong ? getStreamUrl(currentSong.id) : undefined}
                    onTimeUpdate={handleTimeUpdate}
                    onEnded={onNext}
                    onLoadedMetadata={() => setDuration(audioRef.current?.duration || 0)}
                />
            </>
        );
    }

    // Full view mode - the complete Now Playing page
    return (
        <>
            {/* Main Content Area */}
            <div className="flex-1 flex">
                {/* Main Now Playing Area */}
                <div className="flex-1 flex flex-col items-center justify-center pb-8 relative overflow-hidden">
                    {/* Background blur from album art */}
                    <div
                        className="absolute inset-0 bg-cover bg-center opacity-30 blur-3xl scale-150"
                        style={{
                            backgroundImage: currentSong?.cover_art
                                ? `url(${currentSong.cover_art})`
                                : 'linear-gradient(135deg, #ec4899 0%, #9333ea 50%, #1a1a2e 100%)'
                        }}
                    />

                    {/* Song/Video Toggle */}
                    <ModeToggle className="z-20 mb-6" />

                    {/* Content Area - Video or Album Art */}
                    {mode === 'video' && hasVideo ? (
                        <div className="relative z-10 mb-6 w-full max-w-2xl aspect-video rounded-xl overflow-hidden bg-black/50">
                            {videoLoading && (
                                <div className="absolute inset-0 flex items-center justify-center">
                                    <div className="w-12 h-12 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
                                </div>
                            )}
                            {videoError ? (
                                <div className="absolute inset-0 flex flex-col items-center justify-center text-white/70">
                                    <svg className="w-12 h-12 mb-2 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                                    </svg>
                                    <p>{videoError}</p>
                                    <button
                                        onClick={() => switchMode('audio')}
                                        className="mt-3 px-4 py-2 bg-pink-500 rounded-lg text-sm"
                                    >
                                        Switch to Audio
                                    </button>
                                </div>
                            ) : (
                                <video
                                    ref={videoRef}
                                    src={currentSong ? getVideoStreamUrl(currentSong.id) : undefined}
                                    className="w-full h-full object-contain"
                                    onTimeUpdate={handleTimeUpdate}
                                    onEnded={onNext}
                                    onLoadedMetadata={handleVideoLoaded}
                                    onError={handleVideoError}
                                    controls={false}
                                    playsInline
                                />
                            )}
                        </div>
                    ) : (
                        /* Album Art (Audio Mode) */
                        <div className={`relative z-10 mb-6 ${isPlaying ? 'animate-spin-slow' : ''}`}>
                            <div className="w-44 h-44 rounded-full bg-gradient-to-br from-pink-500/30 to-purple-600/30 flex items-center justify-center shadow-2xl shadow-pink-500/20 border-4 border-white/10">
                                {currentSong?.cover_art ? (
                                    <img
                                        src={currentSong.cover_art}
                                        alt="Album Art"
                                        className="w-full h-full rounded-full object-cover"
                                    />
                                ) : (
                                    <div className="w-full h-full rounded-full bg-gradient-to-br from-slate-800 to-slate-900 flex items-center justify-center">
                                        <svg className={`w-16 h-16 text-pink-500/60 ${!currentSong ? 'animate-pulse' : ''}`} fill="currentColor" viewBox="0 0 24 24">
                                            <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                                        </svg>
                                    </div>
                                )}
                            </div>
                            {/* Vinyl record inner ring */}
                            <div className="absolute inset-0 rounded-full border-4 border-white/5 pointer-events-none" />
                            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-slate-900/80 border-2 border-white/10 pointer-events-none" />
                        </div>
                    )}

                    {/* Visualizer (Audio mode only) */}
                    {mode === 'audio' && isPlaying && currentSong && (
                        <div className="flex items-end justify-center gap-1 h-12 mb-4 z-10">
                            {[...Array(25)].map((_, i) => (
                                <div
                                    key={i}
                                    className="w-1 bg-gradient-to-t from-pink-500 to-purple-400 rounded-full visualizer-bar"
                                    style={{
                                        animationDelay: `${Math.random() * 0.5}s`,
                                        animationDuration: `${0.3 + Math.random() * 0.3}s`
                                    }}
                                />
                            ))}
                        </div>
                    )}

                    {/* Song Info */}
                    {currentSong ? (
                        <div className="text-center z-10 animate-fade-in">
                            <h1 className="text-2xl font-bold mb-1 bg-gradient-to-r from-white to-white/80 bg-clip-text text-transparent">{currentSong.title || "Unknown Title"}</h1>
                            <p className="text-base text-white/60">{currentSong.artist || "Unknown Artist"}</p>
                        </div>
                    ) : (
                        <div className="text-center z-10">
                            <h1 className="text-xl font-semibold text-white/50 mb-1">No song playing</h1>
                            <p className="text-white/30 text-sm">Click a song from the queue to start →</p>
                        </div>
                    )}

                    {/* Progress Bar & Controls */}
                    <div className="w-full max-w-md px-8 mt-6 z-10">
                        <div className="flex items-center gap-3 mb-4">
                            <span className="text-xs text-white/40 w-10 text-right">{formatTime(progress)}</span>
                            <div className="flex-1 relative h-1.5 bg-white/10 rounded-full overflow-hidden">
                                <div
                                    className="absolute left-0 top-0 h-full bg-gradient-to-r from-pink-500 to-pink-400 rounded-full transition-all"
                                    style={{ width: `${progressPercent}%` }}
                                />
                                <input
                                    type="range"
                                    min="0"
                                    max={duration || 100}
                                    value={progress}
                                    onChange={handleSeek}
                                    className="absolute inset-0 w-full opacity-0 cursor-pointer"
                                />
                            </div>
                            <span className="text-xs text-white/40 w-10">{formatTime(duration)}</span>
                        </div>

                        {/* Playback Controls */}
                        <div className="flex items-center justify-center gap-6">
                            <button onClick={onPrev} className="control-btn control-btn-secondary w-12 h-12">
                                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                                    <path d="M6 6h2v12H6V6zm3.5 6 8.5 6V6l-8.5 6z" />
                                </svg>
                            </button>
                            <button
                                onClick={togglePlay}
                                className="control-btn control-btn-primary w-16 h-16"
                                disabled={!currentSong}
                            >
                                {isPlaying ? (
                                    <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
                                        <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" />
                                    </svg>
                                ) : (
                                    <svg className="w-7 h-7 ml-1" fill="currentColor" viewBox="0 0 24 24">
                                        <path d="M8 5v14l11-7z" />
                                    </svg>
                                )}
                            </button>
                            <button onClick={onNext} className="control-btn control-btn-secondary w-12 h-12">
                                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                                    <path d="M6 18l8.5-6L6 6v12zm2 0h2V6h-2v12z" transform="scale(-1, 1) translate(-24, 0)" />
                                </svg>
                            </button>
                        </div>
                    </div>
                </div>

                {/* Right Sidebar - Playlist */}
                <div className="w-80 glass-dark border-l border-white/5 flex flex-col">
                    <div className="p-4 border-b border-white/5">
                        <h2 className="text-sm font-semibold text-white/60 uppercase tracking-wider">Up Next</h2>
                    </div>
                    <div className="flex-1 overflow-y-auto">
                        {playlist.slice(0, 10).map((song, index) => (
                            <div
                                key={song.id}
                                className={`song-item flex items-center gap-3 p-3 cursor-pointer border-b border-white/5
                  ${currentSong?.id === song.id ? 'bg-pink-500/10' : ''}`}
                                onClick={() => onSelectSong(song)}
                            >
                                <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-pink-500/20 to-purple-600/20 flex items-center justify-center flex-shrink-0 overflow-hidden">
                                    {currentSong?.id === song.id && isPlaying ? (
                                        <div className="flex items-end gap-0.5 h-4">
                                            {[...Array(3)].map((_, i) => (
                                                <div key={i} className="w-1 bg-pink-500 rounded-full visualizer-bar" style={{ animationDelay: `${i * 0.1}s` }} />
                                            ))}
                                        </div>
                                    ) : (song.cover_art || song.thumbnail) ? (
                                        <img src={song.cover_art || song.thumbnail} alt="" className="w-full h-full object-cover" />
                                    ) : (
                                        <span className="text-white/40 text-sm">{index + 1}</span>
                                    )}
                                </div>
                                <div className="flex-1 min-w-0">
                                    <p className="font-medium truncate text-sm">{song.title || "Unknown"}</p>
                                    <p className="text-xs text-white/40 truncate">{song.artist || "Unknown"}</p>
                                </div>
                                <span className="text-xs text-white/40">
                                    {song.duration ? formatTime(song.duration) : "—"}
                                </span>
                            </div>
                        ))}
                        {playlist.length === 0 && (
                            <div className="p-8 text-center text-white/30">
                                <p>No songs in queue</p>
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Hidden audio element (always present for audio mode) */}
            <audio
                ref={audioRef}
                src={currentSong ? getStreamUrl(currentSong.id) : undefined}
                onTimeUpdate={mode === 'audio' ? handleTimeUpdate : undefined}
                onEnded={onNext}
                onLoadedMetadata={() => setDuration(audioRef.current?.duration || 0)}
                style={{ display: 'none' }}
            />
        </>
    );
};

export default Player;
