import React, { useState, useEffect, useRef } from 'react';
import { submitYoutubeUrl, getYoutubeStatus, getYoutubePreview, listYoutubeTasks, clearYoutubeTasks, deleteYoutubeTask, getYoutubeFormats } from './api';

const YouTube = ({ onDownloadComplete, initialQuery }) => {
    const [url, setUrl] = useState('');
    const [preview, setPreview] = useState(null);
    const [loading, setLoading] = useState(false);
    // Removed blocking 'downloading' state
    const [error, setError] = useState('');
    const [quality, setQuality] = useState('320');

    // Tasks State
    const [tasks, setTasks] = useState([]);
    const [taskPagination, setTaskPagination] = useState({ page: 1, pages: 1, total: 0 });
    const [showHistory, setShowHistory] = useState(true); // Always show history/queue
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
        // Don't set loadingTasks on polling to avoid flicker
        try {
            const result = await listYoutubeTasks(page, 10); // Check 10 items
            setTasks(result.tasks || []);
            setTaskPagination({
                page: result.page,
                pages: result.pages,
                total: result.total
            });
            return result.tasks || [];
        } catch (err) {
            console.error('Failed to load tasks:', err);
            return [];
        }
    };

    // Global Polling for tasks
    useEffect(() => {
        loadTasks(); // Initial load

        // Poll every 2 seconds
        const interval = setInterval(async () => {
            const currentTasks = await loadTasks();

            // If any task is running/queued, keep polling accurately
            // If all are complete/failed, we could slow down, but for now fixed interval is fine
            const hasActive = currentTasks.some(t => ['queued', 'downloading', 'converting', 'uploading_to_telegram', 'uploading_video'].includes(t.status));

            if (!hasActive && pollRef.current) {
                // Optional: Slow down polling if nothing active?
            }
        }, 2000);

        return () => clearInterval(interval);
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

        // Reset only if clearing
        if (!newUrl) {
            setPreview(null);
            setAvailableFormats([]);
            return;
        }

        if (newUrl && isValidYoutubeUrl(newUrl)) {
            setLoading(true);
            try {
                // Fetch preview and formats in parallel
                // Debounce could be added here ideally
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
                // Don't show error immediately on typing, wait for submit
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

        setError('');

        try {
            // Submit and forget - the poller will pick it up
            await submitYoutubeUrl(url, quality);

            // Immediate feedback
            setUrl('');
            setPreview(null);
            setAvailableFormats([]);
            setQuality('320');

            // Force an immediate reload to show the "Queued" task instantly
            setTimeout(() => loadTasks(), 200);

        } catch (err) {
            setError(err.response?.data?.detail || 'Failed to start download');
        }
    };

    const handleDeleteTask = async (taskId, e) => {
        e.stopPropagation();
        if (confirm('Delete this task from history?')) {
            await deleteYoutubeTask(taskId);
            loadTasks();
        }
    };

    const handleClearHistory = async () => {
        if (confirm('Clear all task history?')) {
            await clearYoutubeTasks();
            loadTasks();
        }
    };

    const getStatusColor = (status) => {
        switch (status) {
            case 'completed': return 'bg-green-500';
            case 'failed': return 'bg-red-500';
            case 'cancelled': return 'bg-gray-500';
            default: return 'bg-pink-500';
        }
    };

    return (
        <div className="flex flex-col h-full bg-[#0f0f13] text-white p-8 overflow-y-auto">
            <div className="max-w-4xl mx-auto w-full">

                {/* Header Section with Icon */}
                <div className="text-center mb-8">
                    <div className="w-16 h-16 bg-red-600 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg shadow-red-900/20">
                        <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M19.615 3.184c-3.604-.246-11.631-.245-15.23 0-3.897.266-4.356 2.62-4.385 8.816.029 6.185.484 8.549 4.385 8.816 3.6.245 11.626.246 15.23 0 3.897-.266 4.356-2.62 4.385-8.816-.029-6.185-.484-8.549-4.385-8.816zm-10.615 12.816v-8l8 3.993-8 4.007z" />
                        </svg>
                    </div>
                    <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-red-500 to-pink-600">
                        YouTube to Audio
                    </h1>
                    <p className="text-gray-400 mt-2">Queue high-quality downloads from any YouTube video</p>
                </div>

                {/* Input Card */}
                <div className="bg-[#18181b] border border-white/5 rounded-2xl p-6 mb-8 shadow-xl">
                    <div className="flex flex-col gap-4">
                        <div className="flex gap-2">
                            <div className="flex-1 relative group">
                                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                                    <svg className="h-5 w-5 text-gray-400 group-focus-within:text-pink-500 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                                    </svg>
                                </div>
                                <input
                                    type="text"
                                    value={url}
                                    onChange={handleUrlChange}
                                    placeholder="Paste YouTube link here..."
                                    className="block w-full pl-10 pr-3 py-3 border border-white/10 rounded-xl leading-5 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-pink-500/50 focus:border-pink-500 transition-all"
                                    onKeyDown={(e) => e.key === 'Enter' && handleDownload()}
                                />
                            </div>
                            <select
                                value={quality}
                                onChange={(e) => setQuality(e.target.value)}
                                className="bg-[#27272a] border border-white/10 text-white rounded-xl px-4 py-2 focus:outline-none focus:ring-2 focus:ring-pink-500/50 transition-all appearance-none cursor-pointer hover:bg-[#3f3f46]"
                            >
                                {(availableFormats.length > 0 ? availableFormats : defaultQualityOptions).map(opt => (
                                    <option key={opt.value} value={opt.value}>{opt.label}</option>
                                ))}
                            </select>
                        </div>

                        {/* Valid URL Preview */}
                        {preview && (
                            <div className="flex gap-4 bg-white/5 p-3 rounded-xl animate-fade-in border border-white/5">
                                <img
                                    src={preview.thumbnail}
                                    className="w-24 h-16 object-cover rounded-lg shadow-sm"
                                    alt="Thumbnail"
                                />
                                <div className="flex-1 min-w-0 flex flex-col justify-center">
                                    <h3 className="font-medium text-white truncate" title={preview.title}>{preview.title}</h3>
                                    <p className="text-sm text-gray-400 truncate">{preview.channel} • {preview.duration_string}</p>
                                </div>
                                <div className="flex items-center">
                                    <button
                                        onClick={handleDownload}
                                        className="bg-white text-black hover:bg-gray-200 px-6 py-2 rounded-full font-medium transition-transform transform active:scale-95 flex items-center gap-2 shadow-lg shadow-white/10"
                                    >
                                        <span>Queue</span>
                                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" /></svg>
                                    </button>
                                </div>
                            </div>
                        )}

                        {error && (
                            <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-4 py-3 rounded-xl flex items-center gap-2 text-sm">
                                <svg className="w-5 h-5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                                {error}
                            </div>
                        )}
                    </div>
                </div>

                {/* Queue / History Section */}
                <div className="flex items-center justify-between mb-4">
                    <h2 className="text-xl font-bold flex items-center gap-2">
                        <span className="w-2 h-8 bg-pink-500 rounded-full inline-block"></span>
                        Download Queue
                        {tasks.some(t => !['completed', 'failed'].includes(t.status)) && (
                            <span className="text-xs bg-pink-500/20 text-pink-400 px-2 py-1 rounded-full animate-pulse">Processing</span>
                        )}
                    </h2>
                    {tasks.length > 0 && (
                        <button
                            onClick={handleClearHistory}
                            className="text-xs text-white/50 hover:text-white transition"
                        >
                            Clear History
                        </button>
                    )}
                </div>

                <div className="space-y-3">
                    {tasks.length === 0 ? (
                        <div className="text-center py-12 border-2 border-dashed border-white/5 rounded-2xl">
                            <svg className="w-12 h-12 text-white/10 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" /></svg>
                            <p className="text-gray-500">Your download queue is empty</p>
                        </div>
                    ) : (
                        tasks.map((task) => (
                            <div key={task.task_id} className="bg-[#18181b] border border-white/5 p-4 rounded-xl flex items-center gap-4 group hover:border-white/10 transition-colors">
                                {/* Thumbnail or Icon */}
                                {task.thumbnail ? (
                                    <img src={task.thumbnail} className="w-16 h-16 object-cover rounded-lg bg-black/50" alt="" />
                                ) : (
                                    <div className="w-16 h-16 bg-white/5 rounded-lg flex items-center justify-center">
                                        <svg className="w-6 h-6 text-white/20" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                                    </div>
                                )}

                                <div className="flex-1 min-w-0">
                                    <div className="flex justify-between items-start mb-1">
                                        <h4 className="font-medium text-white truncate pr-4" title={task.title || task.url}>{task.title || task.url}</h4>
                                        <div className="flex items-center gap-2">
                                            {['completed'].includes(task.status) && (
                                                <span className="text-xs bg-green-500/20 text-green-400 px-2 py-0.5 rounded">Done</span>
                                            )}
                                            {['failed'].includes(task.status) && (
                                                <span className="text-xs bg-red-500/20 text-red-400 px-2 py-0.5 rounded">Failed</span>
                                            )}
                                            <button onClick={(e) => handleDeleteTask(task.task_id, e)} className="text-white/20 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity">
                                                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                                            </button>
                                        </div>
                                    </div>

                                    {/* Progress Bar or Status Text */}
                                    {['completed', 'failed', 'cancelled'].includes(task.status) ? (
                                        <p className="text-xs text-gray-500">
                                            {task.status === 'completed' ? `Added to library • ${task.duration || '0:00'}` : (task.error || 'Check logs for details')}
                                        </p>
                                    ) : (
                                        <div className="w-full">
                                            <div className="flex justify-between text-xs text-gray-400 mb-1">
                                                <span>{task.status === 'downloading' ? 'Downloading...' : 'Processing...'}</span>
                                                <span>{Math.round(task.progress)}%</span>
                                            </div>
                                            <div className="h-1.5 w-full bg-white/10 rounded-full overflow-hidden">
                                                <div
                                                    className={`h-full ${getStatusColor(task.status)} transition-all duration-300`}
                                                    style={{ width: `${task.progress}%` }}
                                                >
                                                    <div className="w-full h-full bg-white/20 animate-pulse"></div>
                                                </div>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            </div>
                        ))
                    )}
                </div>
            </div>
        </div>
    );
};

export default YouTube;
