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
    setVolume
}) => (
    <div ref={videoContainerRef} className={`relative w-full ${isFullscreen ? 'h-screen bg-black' : 'max-w-4xl aspect-video rounded-xl overflow-hidden bg-black/50'} z-10 mb-6 group`}>
        {videoLoading && (
            <div className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none">
                <div className="w-12 h-12 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
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
            onError={(e) => {
                console.error(e);
                setVideoError("Video load failed");
                setVideoLoading(false);
            }}
            controls={false}
            playsInline
            onClick={togglePlay} // Click video to play/pause
        />

        {/* Custom Overlay Controls (Visible on Hover or Pause or Fullscreen activity) */}
        <div className={`absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent p-4 transition-opacity duration-300 ${isPlaying ? 'opacity-0 group-hover:opacity-100' : 'opacity-100'}`}>
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
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                    <button onClick={togglePlay} className="text-white hover:text-pink-400 transition">
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
                <button onClick={toggleFullscreen} className="text-white hover:text-pink-400 transition">
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

// Main Player Component starts here...
