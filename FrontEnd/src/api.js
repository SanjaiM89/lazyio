import axios from 'axios';

const ip = localStorage.getItem('backend_ip') || 'localhost';
const port = localStorage.getItem('backend_port') || '8000';

const getBaseUrl = () => {
    let host = ip;
    // Remove trailing slash
    if (host.endsWith('/')) host = host.slice(0, -1);

    // 1. Handle Protocol
    if (!host.startsWith('http://') && !host.startsWith('https://')) {
        // Default to http, unless it looks like a domain that might be https (user responsibility really, but let's default safe)
        host = `http://${host}`;
    }

    // 2. Handle Port
    // Only append port if:
    // - Port is provided
    // - Port is not empty
    // - Port is not default (80/443)
    // - Host does NOT already have a port (check for : at end of string or after domain)
    if (port && port !== '80' && port !== '443') {
        // robust check for port in host:
        // remove protocol first
        const bareHost = host.split('://')[1];
        // check if bareHost has a colon followed by digits
        const hasPort = /:\d+$/.test(bareHost);

        if (!hasPort) {
            host = `${host}:${port}`;
        }
    }
    return host;
};

const BASE_URL = getBaseUrl();
const API_BASE_URL = `${BASE_URL}/api`;

// WS Url needs to match protocol (http -> ws, https -> wss)
export const getWsUrl = () => {
    let url = BASE_URL;
    if (url.startsWith('https://')) {
        url = url.replace('https://', 'wss://');
    } else {
        url = url.replace('http://', 'ws://');
    }
    return `${url}/ws`;
};

const api = axios.create({
    baseURL: API_BASE_URL,
});


export const getSongs = async () => {
    const response = await api.get('/songs');
    return response.data;
};

export const uploadSongs = async (formData, onProgress) => {
    const response = await api.post('/upload', formData, {
        headers: {
            'Content-Type': 'multipart/form-data',
        },
        onUploadProgress: (progressEvent) => {
            if (onProgress) {
                const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total);
                onProgress(percentCompleted);
            }
        },
        // Increase timeout for large uploads (e.g., 30 mins)
        timeout: 30 * 60 * 1000
    });
    return response.data;
};

export const getRecommendations = async (currentSongId, historyIds) => {
    const response = await api.post('/recommend', null, {
        params: {
            current_song_id: currentSongId,
            // Pass history_ids as repeated query params or change backend to accept json body
            // Backend expects: current_song_id: str, history_ids: list[str] in Query params
            // Let's adjust backend to use JSON body for better handling of lists, 
            // OR use proper query string formatting. 
            // For now, let's fix this in Frontend to pass as query params correctly.
        },
        // proper query param serialization for list
        paramsSerializer: params => {
            let result = `current_song_id=${params.current_song_id}`;
            if (params.historyIds) {
                params.historyIds.forEach(id => result += `&history_ids=${id}`);
            }
            return result;
        }
    });
    // Wait, my backend implementation of recommend expected query params by default in FastAPI if not typed as Body.
    // Let's switch backend `recommend` to use Pydantic model for cleaner body request? 
    // Or just fix the call here. 
    // The current backend signature: `async def recommend(current_song_id: str, history_ids: list[str]):`
    return response.data;
};

export const getSimilarSongs = async (songId, limit = 10) => {
    const response = await api.get(`/recommend/similar/${songId}`, { params: { limit } });
    return response.data;
};


// Helper for streaming URL
export const getStreamUrl = (songId, quality = 'original') => `${API_BASE_URL}/stream/${songId}?quality=${quality}`;

// Helper for video streaming URL
export const getVideoStreamUrl = (songId) => `${API_BASE_URL}/stream/${songId}?type=video`;


// ==================== YouTube API ====================

export const getYoutubePreview = async (url) => {
    const response = await api.post('/youtube/preview', { url });
    return response.data;
};

export const submitYoutubeUrl = async (url, quality = '320') => {
    const response = await api.post('/youtube', { url, quality });
    return response.data;
};

export const getYoutubeStatus = async (taskId) => {
    const response = await api.get(`/youtube/status/${taskId}`);
    return response.data;
};

export const cancelYoutubeDownload = async (taskId) => {
    const response = await api.post(`/youtube/cancel/${taskId}`);
    return response.data;
};

export const listYoutubeTasks = async (page = 1, limit = 10) => {
    const response = await api.get('/youtube/tasks', { params: { page, limit } });
    return response.data;
};

export const clearYoutubeTasks = async () => {
    const response = await api.delete('/youtube/tasks');
    return response.data;
};

export const deleteYoutubeTask = async (taskId) => {
    const response = await api.delete(`/youtube/tasks/${taskId}`);
    return response.data;
};

export const getYoutubeFormats = async (url) => {
    const response = await api.post('/youtube/formats', { url });
    return response.data;
};

// ==================== Songs Management ====================

export const getSongsPaginated = async (page = 1, limit = 20) => {
    const response = await api.get('/songs/paginated', { params: { page, limit } });
    return response.data;
};

export const deleteSong = async (songId) => {
    const response = await api.delete(`/songs/${songId}`);
    return response.data;
};

export const recordPlay = async (songId) => {
    const response = await api.post(`/songs/${songId}/play`);
    return response.data;
};

// ==================== Playlists ====================

export const getPlaylists = async (page = 1, limit = 10) => {
    const response = await api.get('/playlists', { params: { page, limit } });
    return response.data;
};

export const createPlaylist = async (name, songs = []) => {
    const response = await api.post('/playlists', { name, songs });
    return response.data;
};

export const getPlaylist = async (playlistId) => {
    const response = await api.get(`/playlists/${playlistId}`);
    return response.data;
};

export const addSongToPlaylist = async (playlistId, songId) => {
    const response = await api.post(`/playlists/${playlistId}/songs`, null, {
        params: { song_id: songId }
    });
    return response.data;
};

export const removeSongFromPlaylist = async (playlistId, songId) => {
    const response = await api.delete(`/playlists/${playlistId}/songs/${songId}`);
    return response.data;
};

export const deletePlaylist = async (playlistId) => {
    const response = await api.delete(`/playlists/${playlistId}`);
    return response.data;
};

// ==================== Homepage ====================

export const getHomepage = async () => {
    const response = await api.get('/home');
    return response.data;
};

export const refreshHomepage = async () => {
    const response = await api.post('/home/refresh');
    return response.data;
};

export default api;



