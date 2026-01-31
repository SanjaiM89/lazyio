import React, { useState, useRef, useEffect } from 'react';
import { getStreamUrl, getVideoStreamUrl } from './api';

// Video Player Component (Extracted to prevent re-renders)
const VideoPlayer = ({
    videoRef,
    videoContainerRef,
    currentSong,
    isPlaying,
    progress,
    duration,
    formatTime,
    togglePlay,
    toggleFullscreen,
    handleSeek,
    handleTimeUpdate,
    onNext,
    setVideoLoading,
    setDuration,
    setVideoError,
    videoLoading,
    isFullscreen,
    volume,
    setVolume,
    isBuffering
}) => (
    <div ref={videoContainerRef} className={`relative w-full ${isFullscreen ? 'h-screen bg-black' : 'max-w-4xl aspect-video rounded-xl overflow-hidden bg-black/50'} z-10 mb-6 group`}>
        {(videoLoading || isBuffering) && (
            <div className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none bg-black/30">
                <div className="flex flex-col items-center gap-3">
                    <div className="w-12 h-12 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
                    {isBuffering && <span className="text-white/80 text-sm">Buffering...</span>}
                </div>
            </div>
        )}

        <video
            ref={videoRef}
            src={currentSong ? getVideoStreamUrl(currentSong.id) : undefined}
            className="w-full h-full object-contain"
            onTimeUpdate={handleTimeUpdate}
            onEnded={onNext}
            onLoadedMetadata={() => {
                setVideoLoading(false);
                setDuration(videoRef.current?.duration || 0);
                if (isPlaying) videoRef.current.play().catch(console.error);
            }}
            onWaiting={() => setIsBuffering(true)}
            onPlaying={() => setIsBuffering(false)}
            onCanPlay={() => setIsBuffering(false)}
            onError={(e) => {
                console.error(e);
                setVideoError("Video load failed");
                setVideoLoading(false);
                setIsBuffering(false);
            }}
            controls={false}
            playsInline
            onClick={togglePlay} // Click video to play/pause
        />

        {/* Custom Overlay Controls (Visible on Hover or Pause or Fullscreen activity) */}
        <div className={`absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent p-4 transition-opacity duration-300 z-50 ${isPlaying ? 'opacity-0 group-hover:opacity-100' : 'opacity-100'}`}>
            {/* Progress Bar */}
            <div className="flex items-center gap-3 mb-2">
                <span className="text-xs text-white/80 w-10 text-right">{formatTime(progress)}</span>
                <div className="flex-1 relative h-1 bg-white/30 rounded-full cursor-pointer group/progress">
                    <div className="absolute left-0 top-0 h-full bg-pink-500 rounded-full" style={{ width: `${(duration > 0 ? (progress / duration) * 100 : 0)}%` }} />
                    <input
                        type="range"
                        min="0"
                        max={duration || 100}
                        value={progress}
                        onChange={handleSeek}
                        className="absolute inset-0 w-full opacity-0 cursor-pointer"
                    />
                </div>
                <span className="text-xs text-white/80 w-10">{formatTime(duration)}</span>
            </div>

            {/* Buttons */}
            <div className="flex items-center justify-between relative">
                <div className="flex items-center gap-4">
                    <button onClick={togglePlay} className="text-white hover:text-pink-400 transition transform hover:scale-110">
                        {isPlaying ? (
                            <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" /></svg>
                        ) : (
                            <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
                        )}
                    </button>
                    <div className="flex items-center gap-2 group/vol">
                        <svg className="w-5 h-5 text-white/70" fill="currentColor" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z" /></svg>
                        <input type="range" min="0" max="1" step="0.01" value={volume} onChange={(e) => setVolume(parseFloat(e.target.value))} className="w-20 accent-pink-500" />
                    </div>
                </div>

                {/* Fullscreen Button - Explicitly positioned */}
                <button
                    onClick={toggleFullscreen}
                    className="text-white hover:text-pink-400 transition transform hover:scale-110 z-50 p-1 rounded-full hover:bg-white/10"
                    title="Fullscreen"
                >
                    {isFullscreen ? (
                        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z" /></svg>
                    ) : (
                        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z" /></svg>
                    )}
                </button>
            </div>
        </div>
    </div>
);

// Toggle Component
const ModeToggle = ({ currentSong, mode, switchMode }) => {
    if (!currentSong?.has_video) return null;
    return (
        <div className="flex bg-white/10 rounded-full p-1 z-20 mb-6">
            <button
                onClick={() => switchMode('audio')}
                className={`px-4 py-1.5 rounded-full text-sm font-medium transition-all ${mode === 'audio' ? 'bg-white text-black' : 'text-white/70 hover:text-white'}`}
            >
                Song
            </button>
            <button
                onClick={() => switchMode('video')}
                className={`px-4 py-1.5 rounded-full text-sm font-medium transition-all ${mode === 'video' ? 'bg-white text-black' : 'text-white/70 hover:text-white'}`}
            >
                Video
            </button>
        </div>
    );
};

const Player = ({ currentSong, onNext, onPrev, playlist = [], onSelectSong, fullView = false, onToggleView }) => {
    const audioRef = useRef(null);
    const videoRef = useRef(null);
    const videoContainerRef = useRef(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [progress, setProgress] = useState(0);
    const [duration, setDuration] = useState(0);
    const [volume, setVolume] = useState(0.8);
    const [mode, setMode] = useState('audio');
    const [preferredMode, setPreferredMode] = useState('audio'); // User's video preference
    const [videoLoading, setVideoLoading] = useState(false);
    const [videoError, setVideoError] = useState(null);
    const [isFullscreen, setIsFullscreen] = useState(false);
    const [isBuffering, setIsBuffering] = useState(false);

    // Initial load & Song Change
    const hasVideo = currentSong?.hasVideo || currentSong?.has_video;

    useEffect(() => {
        if (!currentSong) return;

        setVideoError(null);
        setIsPlaying(true);

        // If user prefers video AND song has video, use video mode
        if (preferredMode === 'video' && hasVideo) {
            setMode('video');
            // Video will auto-play via onLoadedMetadata
        } else {
            // Fallback to audio (or user prefers audio)
            setMode('audio');
            setTimeout(() => {
                if (audioRef.current) audioRef.current.play().catch(e => console.error("Play error:", e));
            }, 50);
        }
    }, [currentSong, preferredMode, hasVideo]);

    // Volume sync
    useEffect(() => {
        if (audioRef.current) audioRef.current.volume = volume;
        if (videoRef.current) videoRef.current.volume = volume;
    }, [volume]);

    // Handle view collapse - switch to audio if video was playing to keep background playback
    useEffect(() => {
        if (!fullView && mode === 'video') {
            // If checking "default only audio need to play" - effectively we switch to audio
            // so playback continues in background
            switchMode('audio');
        }
    }, [fullView]);

    // Video sync effect
    useEffect(() => {
        if (mode === 'video' && hasVideo) {
            setVideoLoading(true);
            setVideoError(null);
        }
    }, [mode, hasVideo]);

    // Fullscreen change listener
    useEffect(() => {
        const handleFsChange = () => {
            setIsFullscreen(!!document.fullscreenElement);
        };
        document.addEventListener('fullscreenchange', handleFsChange);
        return () => document.removeEventListener('fullscreenchange', handleFsChange);
    }, []);

    const togglePlay = () => {
        const media = mode === 'video' ? videoRef.current : audioRef.current;
        if (media) {
            if (isPlaying) media.pause();
            else media.play();
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

    const switchMode = (newMode) => {
        if (newMode === mode) return;

        // Save user's preference when they manually switch
        setPreferredMode(newMode);

        // Get current time from active media
        const currentTime = mode === 'video'
            ? videoRef.current?.currentTime || 0
            : audioRef.current?.currentTime || 0;

        // Pause current
        if (mode === 'video' && videoRef.current) videoRef.current.pause();
        if (mode === 'audio' && audioRef.current) audioRef.current.pause();

        setMode(newMode);

        // Resume new media at sync time
        setTimeout(() => {
            const newMedia = newMode === 'video' ? videoRef.current : audioRef.current;
            if (newMedia) {
                newMedia.currentTime = currentTime;
                if (isPlaying) {
                    newMedia.play().catch(e => console.error("Media swap play error:", e));
                }
            }
        }, 50);
    };

    const toggleFullscreen = () => {
        if (!videoContainerRef.current) return;
        if (!document.fullscreenElement) {
            videoContainerRef.current.requestFullscreen().catch(e => console.error(e));
        } else {
            document.exitFullscreen();
        }
    };

    const formatTime = (seconds) => {
        if (!seconds || isNaN(seconds)) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? '0' : ''}${s}`;
    };

    const progressPercent = duration > 0 ? (progress / duration) * 100 : 0;

    // Video Player Component and ModeToggle moved to TOP of file
    // (See lines below imports)

    // Full View Content (rendered conditionally at end)
    const FullViewContent = (
        <div className="fixed inset-0 z-40 bg-[#0f0f13] flex flex-col pt-20">
            {/* Background Blur */}
            <div
                className="absolute inset-0 bg-cover bg-center opacity-30 blur-3xl scale-150 pointer-events-none"
                style={{ backgroundImage: currentSong?.cover_art ? `url(${currentSong.cover_art})` : 'linear-gradient(135deg, #ec4899, #9333ea)' }}
            />

            <div className="flex-1 flex overflow-hidden relative z-10">
                {/* Main Content */}
                <div className="flex-1 flex flex-col items-center justify-center p-8">

                    {/* Toggle - Check if current song has video capability */}
                    {currentSong?.has_video && (
                        <ModeToggle currentSong={currentSong} mode={mode} switchMode={switchMode} />
                    )}

                    {/* Content */}
                    {mode === 'video' && hasVideo ? (
                        <VideoPlayer
                            videoRef={videoRef}
                            videoContainerRef={videoContainerRef}
                            currentSong={currentSong}
                            isPlaying={isPlaying}
                            progress={progress}
                            duration={duration}
                            formatTime={formatTime}
                            togglePlay={togglePlay}
                            toggleFullscreen={toggleFullscreen}
                            handleSeek={handleSeek}
                            handleTimeUpdate={handleTimeUpdate}
                            onNext={onNext}
                            setVideoLoading={setVideoLoading}
                            setDuration={setDuration}
                            setVideoError={setVideoError}
                            videoLoading={videoLoading}
                            isFullscreen={isFullscreen}
                            volume={volume}
                            setVolume={setVolume}
                            isBuffering={isBuffering}
                            setIsBuffering={setIsBuffering}
                        />
                    ) : (
                        <div className={`relative z-10 mb-10 ${isPlaying ? 'animate-spin-slow' : ''}`}>
                            <div className="w-64 h-64 md:w-80 md:h-80 rounded-full bg-gradient-to-br from-pink-500/30 to-purple-600/30 flex items-center justify-center shadow-2xl shadow-pink-500/20 border-4 border-white/10">
                                {currentSong?.cover_art ? (
                                    <img src={currentSong.cover_art} alt="" className="w-full h-full rounded-full object-cover" />
                                ) : (
                                    <div className="w-full h-full rounded-full bg-gray-800 flex items-center justify-center">
                                        <svg className="w-24 h-24 text-white/20" fill="currentColor" viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" /></svg>
                                    </div>
                                )}
                            </div>
                            <div className="absolute inset-0 rounded-full border-4 border-white/5 pointer-events-none" />
                            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-16 h-16 rounded-full bg-black/80 border-2 border-white/10 pointer-events-none" />
                        </div>
                    )}

                    {/* Song Info & Controls (Only if NOT in video mode or if user wants consistency) */}
                    {/* Note: Video mode has its own overlay controls now. Audio mode uses main controls. */}
                    {mode === 'audio' && (
                        <div className="w-full max-w-lg z-10">
                            <div className="text-center mb-8">
                                <h1 className="text-3xl font-bold text-white mb-2">{currentSong?.title || "Unknown Title"}</h1>
                                <p className="text-xl text-white/60">{currentSong?.artist || "Unknown Artist"}</p>
                            </div>

                            {/* Progress */}
                            <div className="flex items-center gap-4 mb-8 w-full">
                                <span className="text-xs text-white/60 w-10 text-right font-mono">{formatTime(progress)}</span>
                                <div className="flex-1 h-1.5 bg-white/10 rounded-full cursor-pointer relative group/prog hover:h-2.5 transition-all duration-300">
                                    <div className="absolute left-0 top-0 h-full bg-gradient-to-r from-pink-500 to-purple-600 rounded-full shadow-[0_0_15px_rgba(236,72,153,0.5)]" style={{ width: `${progressPercent}%` }} />
                                    <div className="absolute top-1/2 -translate-y-1/2 w-4 h-4 bg-white rounded-full opacity-0 group-hover/prog:opacity-100 transition shadow-[0_0_10px_rgba(255,255,255,0.8)]" style={{ left: `${progressPercent}%`, marginLeft: '-8px' }} />
                                    <input type="range" min="0" max={duration || 100} value={progress} onChange={handleSeek} className="absolute inset-0 w-full opacity-0 cursor-pointer" />
                                </div>
                                <span className="text-xs text-white/60 w-10 font-mono">{formatTime(duration)}</span>
                            </div>

                            {/* Main Controls */}
                            <div className="flex items-center justify-center gap-10">
                                <button onClick={onPrev} className="text-white/60 hover:text-white transition transform hover:scale-110 hover:drop-shadow-glow">
                                    <svg className="w-10 h-10" fill="currentColor" viewBox="0 0 24 24"><path d="M6 6h2v12H6V6zm3.5 6 8.5 6V6l-8.5 6z" /></svg>
                                </button>
                                <button onClick={togglePlay} className="w-20 h-20 rounded-full bg-white text-black flex items-center justify-center hover:scale-105 transition shadow-[0_0_30px_rgba(255,255,255,0.3)] hover:shadow-[0_0_50px_rgba(255,255,255,0.5)]">
                                    {isPlaying ? (
                                        <svg className="w-10 h-10" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" /></svg>
                                    ) : (
                                        <svg className="w-10 h-10 ml-1.5" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
                                    )}
                                </button>
                                <button onClick={onNext} className="text-white/60 hover:text-white transition transform hover:scale-110 hover:drop-shadow-glow">
                                    <svg className="w-10 h-10" fill="currentColor" viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zm2 0h2V6h-2v12z" transform="scale(-1, 1) translate(-24, 0)" /></svg>
                                </button>
                            </div>
                        </div>
                    )}
                </div>
                {/* Right Playlist Sidebar (Optional in full view) */}
                <div className="w-80 glass-dark border-l border-white/5 flex flex-col hidden lg:flex">
                    <div className="p-6"><h2 className="text-white/60 font-semibold uppercase tracking-wider text-sm">Up Next</h2></div>
                    <div className="flex-1 overflow-y-auto p-4 space-y-2">
                        {playlist.slice(0, 20).map((song, i) => (
                            <div key={song.id} onClick={() => onSelectSong(song)} className={`p-3 rounded-lg flex items-center gap-3 cursor-pointer hover:bg-white/5 ${currentSong?.id === song.id ? 'bg-white/10' : ''}`}>
                                <img src={song.cover_art} className="w-10 h-10 rounded object-cover bg-gray-800" alt="" />
                                <div className="min-w-0">
                                    <p className="truncate text-sm font-medium text-white">{song.title}</p>
                                    <p className="truncate text-xs text-white/50">{song.artist}</p>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );

    // Mini Bar Content
    const MiniBarContent = (
        <div className="h-24 glass border-t border-white/10 flex items-center px-4 md:px-8 gap-4 md:gap-8 cursor-pointer hover:bg-white/5 transition group/player" onClick={onToggleView}>
            {/* Song Info */}
            <div className="flex items-center gap-4 w-1/3 min-w-0">
                {currentSong ? (
                    <>
                        <div className={`w-14 h-14 rounded-lg bg-gray-800 flex-shrink-0 overflow-hidden relative shadow-lg ${isPlaying ? 'animate-spin-slow' : ''}`}>
                            <img src={currentSong.cover_art} className="w-full h-full object-cover" alt="" />
                            {/* Overlay play icon on hover (hint to expand) */}
                            <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover/player:opacity-100 transition">
                                <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" /></svg>
                            </div>
                        </div>
                        <div className="min-w-0">
                            <p className="font-bold text-white truncate text-base">{currentSong.title}</p>
                            <p className="text-sm text-white/60 truncate">{currentSong.artist}</p>
                        </div>
                    </>
                ) : (
                    <p className="text-white/40 text-sm">No song playing</p>
                )}
            </div>

            {/* Controls (Center) */}
            <div className="flex-1 flex flex-col items-center justify-center max-w-md mx-auto" onClick={e => e.stopPropagation()}>
                <div className="flex items-center gap-8 mb-2">
                    <button onClick={onPrev} className="text-white/60 hover:text-white transition transform hover:scale-110 p-2">
                        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 6h2v12H6V6zm3.5 6 8.5 6V6l-8.5 6z" /></svg>
                    </button>
                    <button onClick={togglePlay} className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center hover:scale-105 transition shadow-lg shadow-white/10 hover:shadow-white/20">
                        {isPlaying ? (
                            <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" /></svg>
                        ) : (
                            <svg className="w-6 h-6 ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
                        )}
                    </button>
                    <button onClick={onNext} className="text-white/60 hover:text-white transition transform hover:scale-110 p-2">
                        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zm2 0h2V6h-2v12z" transform="scale(-1, 1) translate(-24, 0)" /></svg>
                    </button>
                </div>
                {/* Mini Progress */}
                <div className="w-full flex items-center gap-3">
                    <span className="text-xs text-white/40 w-8 text-right font-mono">{formatTime(progress)}</span>
                    <div className="flex-1 h-1 bg-white/10 rounded-full cursor-pointer relative group/prog hover:h-2 transition-all duration-300">
                        <div className="absolute left-0 top-0 h-full bg-gradient-to-r from-pink-500 to-purple-500 rounded-full" style={{ width: `${progressPercent}%` }} />
                        <div className="absolute top-1/2 -translate-y-1/2 w-3 h-3 bg-white rounded-full opacity-0 group-hover/prog:opacity-100 transition shadow-md" style={{ left: `${progressPercent}%`, marginLeft: '-6px' }} />
                        <input type="range" min="0" max={duration || 100} value={progress} onChange={handleSeek} className="absolute inset-0 w-full opacity-0 cursor-pointer" />
                    </div>
                    <span className="text-xs text-white/40 w-8 font-mono">{formatTime(duration)}</span>
                </div>
            </div>

            {/* Volume / Extra */}
            <div className="hidden md:flex items-center gap-3 w-1/3 justify-end" onClick={e => e.stopPropagation()}>
                <button className="text-white/60 hover:text-white">
                    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z" /></svg>
                </button>
                <div className="w-24 h-1 bg-white/10 rounded-full relative group/vol">
                    <div className="absolute left-0 top-0 h-full bg-white rounded-full group-hover/vol:bg-pink-500 transition-colors" style={{ width: `${volume * 100}%` }} />
                    <input type="range" min="0" max="1" step="0.01" value={volume} onChange={e => setVolume(parseFloat(e.target.value))} className="absolute inset-0 w-full opacity-0 cursor-pointer" />
                </div>
            </div>
        </div>
    );

    // SINGLE return point - audio is ALWAYS in same position for both views
    return (
        <>
            {fullView ? FullViewContent : MiniBarContent}
            {/* Persistent Audio - NEVER remounts because it's always at same position */}
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
