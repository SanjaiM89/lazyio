import React, { useState, useCallback, useRef, useEffect } from 'react';
import { uploadSongs, getWsUrl } from './api';

const Upload = ({ onUploadComplete }) => {
    const [files, setFiles] = useState([]);
    const [uploading, setUploading] = useState(false);
    const [uploadProgress, setUploadProgress] = useState({});
    const [uploadStage, setUploadStage] = useState(''); // Current stage message
    const [dragActive, setDragActive] = useState(false);
    const inputRef = useRef(null);
    const wsRef = useRef(null);

    // Connect to WebSocket for upload progress
    useEffect(() => {
        if (uploading) {
            const ws = new WebSocket(getWsUrl());
            wsRef.current = ws;

            ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    if (data.event === 'upload_progress') {
                        const { file_index, total_files, stage, message } = data.data;
                        // Update progress based on stage
                        const stageProgress = {
                            'saving': 10,
                            'metadata': 20,
                            'telegram': 50,
                            'extracting_audio': 70,
                            'database': 90,
                            'complete': 100,
                            'error': -1
                        };
                        const percent = stageProgress[stage] || 0;

                        setUploadProgress(prev => ({
                            ...prev,
                            [file_index]: percent
                        }));
                        setUploadStage(message);
                    } else if (data.event === 'upload_complete') {
                        setUploadStage(`Upload complete! ${data.data.count} file(s) added.`);
                    }
                } catch (e) {
                    console.error('WS parse error:', e);
                }
            };

            ws.onerror = (e) => console.error('WS error:', e);

            return () => {
                ws.close();
            };
        }
    }, [uploading]);

    const handleDrag = useCallback((e) => {
        e.preventDefault();
        e.stopPropagation();
        if (e.type === "dragenter" || e.type === "dragover") {
            setDragActive(true);
        } else if (e.type === "dragleave") {
            setDragActive(false);
        }
    }, []);

    const handleDrop = useCallback((e) => {
        e.preventDefault();
        e.stopPropagation();
        setDragActive(false);

        const droppedFiles = [...e.dataTransfer.files].filter(f =>
            f.type.startsWith('audio/') || f.type.startsWith('video/') ||
            f.name.endsWith('.mp3') || f.name.endsWith('.flac') || f.name.endsWith('.wav') ||
            f.name.endsWith('.m4a') || f.name.endsWith('.mp4') || f.name.endsWith('.mkv') || f.name.endsWith('.webm')
        );
        setFiles(prev => [...prev, ...droppedFiles]);
    }, []);

    const handleChange = (e) => {
        const selectedFiles = [...e.target.files];
        setFiles(prev => [...prev, ...selectedFiles]);
    };

    const removeFile = (index) => {
        setFiles(prev => prev.filter((_, i) => i !== index));
    };

    const handleUpload = async () => {
        if (files.length === 0) return;
        setUploading(true);
        setUploadStage('Preparing upload...');

        const formData = new FormData();
        files.forEach(file => {
            formData.append('files', file);
        });

        try {
            await uploadSongs(formData, (percent) => {
                // HTTP upload progress (file transfer to server)
                if (percent < 100) {
                    setUploadStage(`Uploading to server... ${percent}%`);
                }
                setUploadProgress(prev => {
                    const newProgress = {};
                    files.forEach((_, idx) => newProgress[idx] = Math.min(percent * 0.1, 10)); // First 10%
                    return newProgress;
                });
            });

            // Wait a moment for WebSocket to receive final updates
            setTimeout(() => {
                setFiles([]);
                setUploadProgress({});
                setUploadStage('');
                onUploadComplete?.();
            }, 2000);
        } catch (error) {
            console.error("Upload failed:", error);
            setUploadStage(`Upload failed: ${error.message || 'Network error'}`);
            // Alert with more info
            if (error.response?.status === 502) {
                alert("Server error (502). The backend might be restarting. Please try again in a moment.");
            } else {
                alert("Upload failed! Check console for details.");
            }
        } finally {
            setUploading(false);
        }
    };

    const totalSize = files.reduce((acc, f) => acc + f.size, 0);

    return (
        <div className="flex-1 overflow-y-auto p-8">
            <div className="max-w-3xl mx-auto">
                <div className="text-center mb-12 animate-fade-in">
                    <h1 className="text-4xl font-bold mb-4 bg-gradient-to-r from-pink-500 to-purple-500 bg-clip-text text-transparent">
                        Upload Music & Videos
                    </h1>
                    <p className="text-white/50">Add your favorite tracks and videos to the library</p>
                </div>

                {/* Drop Zone */}
                <div
                    className={`drop-zone glass rounded-2xl p-12 text-center mb-8 transition-all animate-slide-up ${dragActive ? 'active border-pink-500 bg-pink-500/10' : ''}`}
                    onDragEnter={handleDrag}
                    onDragLeave={handleDrag}
                    onDragOver={handleDrag}
                    onDrop={handleDrop}
                    onClick={() => inputRef.current?.click()}
                >
                    <input
                        ref={inputRef}
                        type="file"
                        multiple
                        accept="audio/*,video/*,.mp3,.flac,.wav,.m4a,.ogg,.mp4,.mkv,.webm"
                        onChange={handleChange}
                        className="hidden"
                    />

                    <div className={`w-20 h-20 mx-auto mb-6 rounded-full bg-gradient-to-br from-pink-500/20 to-purple-600/20 flex items-center justify-center ${dragActive ? 'animate-pulse-slow' : ''}`}>
                        <svg className="w-10 h-10 text-pink-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                        </svg>
                    </div>

                    <p className="text-xl font-medium mb-2">
                        {dragActive ? 'Drop your files here' : 'Drag & drop music or video files'}
                    </p>
                    <p className="text-white/40 text-sm">or click to browse • MP3, M4A, MP4, WEBM</p>
                </div>

                {/* File List */}
                {files.length > 0 && (
                    <div className="glass rounded-2xl p-6 mb-6 animate-slide-up" style={{ animationDelay: '0.1s' }}>
                        <div className="flex justify-between items-center mb-4">
                            <h3 className="font-semibold">
                                {files.length} file{files.length > 1 ? 's' : ''} selected
                            </h3>
                            <span className="text-sm text-white/40">
                                {(totalSize / 1024 / 1024).toFixed(2)} MB total
                            </span>
                        </div>

                        <div className="space-y-3 max-h-64 overflow-y-auto">
                            {files.map((file, idx) => {
                                const progress = uploadProgress[idx] || 0;
                                return (
                                    <div
                                        key={idx}
                                        className="flex items-center gap-4 p-3 rounded-xl bg-white/5 relative overflow-hidden group"
                                    >
                                        {/* Progress bg */}
                                        {uploading && (
                                            <div
                                                className="absolute inset-0 bg-gradient-to-r from-pink-500/20 to-purple-600/20 transition-all"
                                                style={{ width: `${progress}%` }}
                                            />
                                        )}

                                        <div className="relative z-10 w-10 h-10 rounded-lg bg-gradient-to-br from-pink-500/30 to-purple-600/30 flex items-center justify-center">
                                            {uploading && progress < 100 ? (
                                                <svg className="w-5 h-5 animate-spin text-pink-500" viewBox="0 0 24 24">
                                                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                                                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                                                </svg>
                                            ) : progress >= 100 ? (
                                                <svg className="w-5 h-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                                </svg>
                                            ) : (
                                                <svg className="w-5 h-5 text-white/40" fill="currentColor" viewBox="0 0 24 24">
                                                    <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                                                </svg>
                                            )}
                                        </div>

                                        <div className="relative z-10 flex-1 min-w-0">
                                            <p className="font-medium truncate text-sm">{file.name}</p>
                                            <p className="text-xs text-white/40">
                                                {(file.size / 1024 / 1024).toFixed(2)} MB
                                                {uploading && <span className="ml-2 text-pink-400">{Math.min(100, Math.round(progress))}%</span>}
                                            </p>
                                        </div>

                                        {!uploading && (
                                            <button
                                                onClick={(e) => { e.stopPropagation(); removeFile(idx); }}
                                                className="relative z-10 opacity-0 group-hover:opacity-100 w-8 h-8 rounded-full bg-red-500/20 hover:bg-red-500/40 flex items-center justify-center transition-all"
                                            >
                                                <svg className="w-4 h-4 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                                                </svg>
                                            </button>
                                        )}
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                )}

                {/* Upload Button */}
                {files.length > 0 && (
                    <div className="text-center animate-slide-up" style={{ animationDelay: '0.2s' }}>
                        <button
                            onClick={handleUpload}
                            disabled={uploading}
                            className={`btn-primary px-12 py-4 text-lg ${uploading ? 'opacity-50 cursor-not-allowed' : ''}`}
                        >
                            {uploading ? (
                                <span className="flex items-center gap-3">
                                    <svg className="w-5 h-5 animate-spin" viewBox="0 0 24 24">
                                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                                    </svg>
                                    Uploading...
                                </span>
                            ) : (
                                `Upload ${files.length} file${files.length > 1 ? 's' : ''}`
                            )}
                        </button>

                        {/* Upload Stage Message */}
                        {uploadStage && (
                            <div className="mt-4 p-3 rounded-xl bg-pink-500/10 border border-pink-500/20">
                                <p className="text-sm text-pink-300">{uploadStage}</p>
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
};

export default Upload;
