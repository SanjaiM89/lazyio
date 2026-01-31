import React, { useState, useEffect, useRef } from 'react';
import { submitYoutubeUrl, getYoutubeStatus, getYoutubePreview, listYoutubeTasks, clearYoutubeTasks, deleteYoutubeTask, getYoutubeFormats } from './api';

const YouTube = ({ onDownloadComplete, initialQuery }) => {
    const [url, setUrl] = useState('');
    const [preview, setPreview] = useState(null);
    const [loading, setLoading] = useState(false);
    const [downloading, setDownloading] = useState(false);
    const [taskId, setTaskId] = useState(null);
    const [status, setStatus] = useState(null);
    const [error, setError] = useState('');
    const [quality, setQuality] = useState('320');
    const [tasks, setTasks] = useState([]);
    const [taskPagination, setTaskPagination] = useState({ page: 1, pages: 1, total: 0 });
    const [showHistory, setShowHistory] = useState(false);
    const [loadingTasks, setLoadingTasks] = useState(false);
    const [availableFormats, setAvailableFormats] = useState([]);
    const pollRef = useRef(null);

    // Default options (fallback)
    const defaultQualityOptions = [
        { value: '320', label: 'Best Quality (320kbps)' },
        { value: '256', label: 'High Quality (256kbps)' },
        { value: '192', label: 'Standard (192kbps)' },
        { value: '128', label: 'Compact (128kbps)' },
        { value: 'm4a', label: 'M4A Format' },
    ];

    const isValidYoutubeUrl = (url) => {
        if (url.startsWith('ytsearch:') || url.startsWith('ytsearch1:')) return true;
        const patterns = [
            /^(https?:\/\/)?(www\.)?youtube\.com\/watch\?v=[\w-]+/,
            /^(https?:\/\/)?(www\.)?youtu\.be\/[\w-]+/,
            /^(https?:\/\/)?(www\.)?youtube\.com\/shorts\/[\w-]+/,
            /^(https?:\/\/)?music\.youtube\.com\/watch\?v=[\w-]+/,
        ];
        return patterns.some(pattern => pattern.test(url));
    };

    const loadTasks = async (page = 1) => {
        setLoadingTasks(true);
        try {
            const result = await listYoutubeTasks(page, 5);
            setTasks(result.tasks || []);
            setTaskPagination({
                page: result.page,
                pages: result.pages,
                total: result.total
            });
        } catch (err) {
            console.error('Failed to load tasks:', err);
        } finally {
            setLoadingTasks(false);
        }
    };

    useEffect(() => {
        loadTasks();
    }, []);

    // Handle initial query from navigation
    useEffect(() => {
        if (initialQuery) {
            const isUrl = /^(https?:\/\/)/.test(initialQuery);
            if (isUrl) {
                setUrl(initialQuery);
                handleUrlChange({ target: { value: initialQuery } });
            } else {
                const searchUrl = `ytsearch1:${initialQuery}`;
                setUrl(searchUrl);
                handleUrlChange({ target: { value: searchUrl } });
            }
        }
    }, [initialQuery]);

    const handleUrlChange = async (e) => {
        const newUrl = e.target.value;
        setUrl(newUrl);
        setError('');
        setPreview(null);
        setAvailableFormats([]);
        setQuality('320');

        if (newUrl && isValidYoutubeUrl(newUrl)) {
            setLoading(true);
            try {
                // Fetch preview and formats in parallel
                const [previewResult, formatsResult] = await Promise.all([
                    getYoutubePreview(newUrl),
                    getYoutubeFormats(newUrl).catch(() => ({ formats: [] }))
                ]);

                if (previewResult.status === 'success') {
                    setPreview(previewResult.data);
                }

                if (formatsResult.formats && formatsResult.formats.length > 0) {
                    const dynamicOptions = formatsResult.formats.map(f => ({
                        value: f.format_id,
                        label: `${f.ext.toUpperCase()} - ${f.abr ? Math.round(f.abr) + 'kbps' : (f.note || f.quality || 'Unknown')} ${f.filesize ? '(' + (f.filesize / 1024 / 1024).toFixed(1) + 'MB)' : ''}`
                    }));
                    setAvailableFormats(dynamicOptions);
                    if (dynamicOptions.length > 0) {
                        setQuality(dynamicOptions[0].value);
                    }
                }
            } catch (err) {
                console.error(err);
                setError('Could not fetch video info');
            } finally {
                setLoading(false);
            }
        }
    };

    const handleDownload = async () => {
        if (!url || !isValidYoutubeUrl(url)) {
            setError('Please enter a valid YouTube URL');
            return;
        }

        setDownloading(true);
        setError('');
        setStatus(null);

        try {
            const result = await submitYoutubeUrl(url, quality);
            setTaskId(result.task_id);

            pollRef.current = setInterval(async () => {
                try {
                    const statusResult = await getYoutubeStatus(result.task_id);
                    setStatus(statusResult);

                    if (['completed', 'failed', 'cancelled'].includes(statusResult.status)) {
                        clearInterval(pollRef.current);
                        setDownloading(false);
                        loadTasks();

                        if (statusResult.status === 'completed') {
                            setTimeout(() => {
                                onDownloadComplete?.();
                                setUrl('');
                                setPreview(null);
                                setStatus(null);
                                setTaskId(null);
                                setAvailableFormats([]);
                            }, 1500);
                        } else if (statusResult.status === 'failed') {
                            setError(statusResult.error || 'Download failed');
                        }
                    }
                } catch (err) {
                    console.error('Status poll error:', err);
                }
            }, 1000);
        } catch (err) {
            setError(err.message || 'Failed to start download');
            setDownloading(false);
        }
    };

    const handleClearAll = async () => {
        if (!confirm('Clear all download history?')) return;
        try {
            await clearYoutubeTasks();
            setTasks([]);
            setTaskPagination({ page: 1, pages: 1, total: 0 });
        } catch (err) {
            console.error('Failed to clear tasks:', err);
        }
    };

    const handleDeleteTask = async (taskId) => {
        try {
            await deleteYoutubeTask(taskId);
            loadTasks(taskPagination.page);
        } catch (err) {
            console.error('Failed to delete task:', err);
        }
    };

    useEffect(() => {
        return () => {
            if (pollRef.current) clearInterval(pollRef.current);
        };
    }, []);

    const formatDuration = (seconds) => {
        if (!seconds) return '--:--';
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    const getStatusText = (statusVal) => {
        switch (statusVal) {
            case 'pending': return 'Preparing...';
            case 'fetching_info': return 'Fetching...';
            case 'downloading': return 'Downloading...';
            case 'converting': return 'Converting...';
            case 'uploading': return 'Uploading...';
            case 'completed': return '✓ Complete';
            case 'failed': return '✗ Failed';
            case 'cancelled': return 'Cancelled';
            default: return statusVal;
        }
    };

    const getStatusColor = (statusVal) => {
        switch (statusVal) {
            case 'completed': return 'text-green-400';
            case 'failed': return 'text-red-400';
            case 'cancelled': return 'text-yellow-400';
            default: return 'text-white/50';
        }
    };

    // Render Helpers
    const renderQualitySelector = () => (
        <div className="flex flex-col sm:flex-row gap-4 mb-6 animate-slide-up" style={{ animationDelay: '0.15s' }}>
            <div className="flex-1">
                <label className="block text-sm text-white/50 mb-2">
                    {availableFormats.length > 0 ? 'Select Format' : 'Audio Quality'}
                </label>
                <select
                    value={quality}
                    onChange={(e) => setQuality(e.target.value)}
                    className="w-full bg-white/5 border border-white/10 rounded-xl py-3 px-4 text-white focus:outline-none focus:border-pink-500/50 transition-all appearance-none cursor-pointer"
                    style={{ backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='white'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 9l-7 7-7-7'%3E%3C/path%3E%3C/svg%3E")`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 12px center', backgroundSize: '16px' }}
                >
                    {(availableFormats.length > 0 ? availableFormats : defaultQualityOptions).map(opt => (
                        <option key={opt.value} value={opt.value} className="bg-gray-900">
                            {opt.label}
                        </option>
                    ))}
                </select>
            </div>
            <div className="flex items-end">
                <button
                    onClick={handleDownload}
                    className="btn-primary px-8 py-3 flex items-center gap-2 w-full sm:w-auto justify-center"
                >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                    </svg>
                    Download
                </button>
            </div>
        </div>
    );

    return (
        <div className="flex-1 overflow-y-auto p-8">
            <div className="max-w-2xl mx-auto">
                <div className="text-center mb-10 animate-fade-in">
                    <div className="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-gradient-to-br from-red-500/20 to-pink-600/20 mb-6">
                        <svg className="w-10 h-10 text-red-500" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" />
                        </svg>
                    </div>
                    <h1 className="text-4xl font-bold mb-3 bg-gradient-to-r from-red-500 to-pink-500 bg-clip-text text-transparent">
                        YouTube to Audio
                    </h1>
                    <p className="text-white/50">Download high-quality audio from any YouTube video</p>
                </div>

                <div className="glass rounded-2xl p-6 mb-6 animate-slide-up">
                    <div className="relative">
                        <div className="absolute inset-y-0 left-4 flex items-center pointer-events-none">
                            <svg className="w-5 h-5 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                            </svg>
                        </div>
                        <input
                            type="text"
                            value={url}
                            onChange={handleUrlChange}
                            placeholder="Paste YouTube URL here..."
                            className="w-full bg-white/5 border border-white/10 rounded-xl py-4 pl-12 pr-4 text-white placeholder-white/30 focus:outline-none focus:border-pink-500/50 focus:ring-2 focus:ring-pink-500/20 transition-all"
                            disabled={downloading}
                        />
                        {loading && (
                            <div className="absolute inset-y-0 right-4 flex items-center">
                                <div className="w-5 h-5 rounded-full border-2 border-pink-500/30 border-t-pink-500 animate-spin" />
                            </div>
                        )}
                    </div>

                    {error && (
                        <p className="mt-3 text-red-400 text-sm flex items-center gap-2">
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            {error}
                        </p>
                    )}
                </div>

                {preview && !downloading && (
                    <div className="glass rounded-2xl overflow-hidden mb-6 animate-slide-up" style={{ animationDelay: '0.1s' }}>
                        <div className="flex gap-4 p-4">
                            <div className="relative w-40 h-24 rounded-xl overflow-hidden flex-shrink-0">
                                {preview.thumbnail ? (
                                    <img src={preview.thumbnail} alt={preview.title} className="w-full h-full object-cover" />
                                ) : (
                                    <div className="w-full h-full bg-white/10 flex items-center justify-center">
                                        <svg className="w-8 h-8 text-white/20" fill="currentColor" viewBox="0 0 24 24">
                                            <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                                        </svg>
                                    </div>
                                )}
                                <div className="absolute bottom-1 right-1 bg-black/80 px-1.5 py-0.5 rounded text-xs">
                                    {formatDuration(preview.duration)}
                                </div>
                            </div>
                            <div className="flex-1 min-w-0">
                                <h3 className="font-semibold text-lg truncate mb-1">{preview.title}</h3>
                                <p className="text-white/50 text-sm truncate">{preview.artist || preview.channel}</p>
                                {preview.view_count && (
                                    <p className="text-white/30 text-xs mt-2">
                                        {(preview.view_count / 1000000).toFixed(1)}M views
                                    </p>
                                )}
                            </div>
                        </div>
                    </div>
                )}

                {preview && !downloading && renderQualitySelector()}

                {downloading && status && (
                    <div className="glass rounded-2xl p-6 mb-6 animate-slide-up">
                        <div className="flex items-center gap-4 mb-4">
                            {preview?.thumbnail && (
                                <img src={preview.thumbnail} alt="" className="w-16 h-16 rounded-lg object-cover" />
                            )}
                            <div className="flex-1 min-w-0">
                                <p className="font-semibold truncate">{status.title || preview?.title || 'Downloading...'}</p>
                                <p className="text-sm text-white/50">{status.artist || preview?.artist || ''}</p>
                            </div>
                        </div>

                        <div className="relative h-2 bg-white/10 rounded-full overflow-hidden mb-3">
                            <div
                                className={`absolute inset-y-0 left-0 rounded-full transition-all duration-300 ${status.status === 'completed' ? 'bg-green-500' : status.status === 'failed' ? 'bg-red-500' : 'bg-gradient-to-r from-pink-500 to-purple-500'}`}
                                style={{ width: `${status.progress || 0}%` }}
                            />
                            {status.status !== 'completed' && status.status !== 'failed' && (
                                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent animate-shimmer" />
                            )}
                        </div>

                        <div className="flex justify-between items-center text-sm">
                            <span className={getStatusColor(status.status)}>{getStatusText(status.status)}</span>
                            <span className="text-white/50">{Math.round(status.progress || 0)}%</span>
                        </div>

                        {status.status === 'completed' && (
                            <div className="mt-4 text-center">
                                <p className="text-green-400 flex items-center justify-center gap-2">
                                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                    </svg>
                                    Added to your library!
                                </p>
                            </div>
                        )}
                    </div>
                )}

                <div className="glass rounded-2xl p-6 animate-slide-up" style={{ animationDelay: '0.25s' }}>
                    <div className="flex justify-between items-center mb-4">
                        <button
                            onClick={() => { setShowHistory(!showHistory); if (!showHistory) loadTasks(); }}
                            className="flex items-center gap-2 text-white/70 hover:text-white transition"
                        >
                            <svg className={`w-4 h-4 transition-transform ${showHistory ? 'rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                            </svg>
                            <span className="font-medium">Download History</span>
                            {taskPagination.total > 0 && (
                                <span className="text-xs bg-white/10 px-2 py-0.5 rounded-full">{taskPagination.total}</span>
                            )}
                        </button>

                        {showHistory && tasks.length > 0 && (
                            <button
                                onClick={handleClearAll}
                                className="text-sm text-red-400 hover:text-red-300 transition flex items-center gap-1"
                            >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                </svg>
                                Clear All
                            </button>
                        )}
                    </div>

                    {showHistory && (
                        <>
                            {loadingTasks ? (
                                <div className="flex justify-center py-8">
                                    <div className="w-8 h-8 rounded-full border-2 border-pink-500/30 border-t-pink-500 animate-spin" />
                                </div>
                            ) : tasks.length === 0 ? (
                                <div className="text-center py-8 text-white/30">
                                    <p>No download history yet</p>
                                </div>
                            ) : (
                                <div className="space-y-3">
                                    {tasks.map((task) => (
                                        <div key={task.task_id} className="flex items-center gap-3 p-3 rounded-xl bg-white/5 group">
                                            {task.thumbnail && (
                                                <img src={task.thumbnail} alt="" className="w-12 h-12 rounded-lg object-cover flex-shrink-0" />
                                            )}
                                            <div className="flex-1 min-w-0">
                                                <p className="font-medium text-sm truncate">{task.title || 'Unknown'}</p>
                                                <p className="text-xs text-white/40 truncate">{task.artist || ''}</p>
                                            </div>
                                            <div className="flex items-center gap-2">
                                                <span className={`text-xs ${getStatusColor(task.status)}`}>{getStatusText(task.status)}</span>
                                                <button
                                                    onClick={() => handleDeleteTask(task.task_id)}
                                                    className="opacity-0 group-hover:opacity-100 p-1 hover:bg-red-500/20 rounded transition"
                                                >
                                                    <svg className="w-4 h-4 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                                                    </svg>
                                                </button>
                                            </div>
                                        </div>
                                    ))}

                                    {taskPagination.pages > 1 && (
                                        <div className="flex justify-center items-center gap-2 pt-4">
                                            <button
                                                onClick={() => loadTasks(taskPagination.page - 1)}
                                                disabled={taskPagination.page <= 1}
                                                className="px-3 py-1 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition"
                                            >
                                                ←
                                            </button>
                                            <span className="text-sm text-white/50">{taskPagination.page} / {taskPagination.pages}</span>
                                            <button
                                                onClick={() => loadTasks(taskPagination.page + 1)}
                                                disabled={taskPagination.page >= taskPagination.pages}
                                                className="px-3 py-1 rounded-lg bg-white/5 hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition"
                                            >
                                                →
                                            </button>
                                        </div>
                                    )}
                                </div>
                            )}
                        </>
                    )}
                </div>

                <style>{`
                    @keyframes shimmer {
                        0% { transform: translateX(-100%); }
                        100% { transform: translateX(100%); }
                    }
                    .animate-shimmer {
                        animation: shimmer 1.5s infinite;
                    }
                `}</style>
            </div>
        </div>
    );
};

export default YouTube;
