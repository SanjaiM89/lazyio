import React, { useState, useEffect } from 'react';
import { getSongs, recordPlay, getWsUrl, getHomepage, deleteSong } from './api';
import Player from './Player';
import Upload from './Upload';
import YouTube from './YouTube';
import Home from './Home';
import Playlists from './Playlists';
import AddToPlaylistModal from './AddToPlaylistModal';
import SongMenu from './SongMenu';
import SettingsModal from './SettingsModal';
import SmartSearch from './SmartSearch';

function App() {
  const [currentSong, setCurrentSong] = useState(null);
  const [songs, setSongs] = useState([]);
  const [homepageData, setHomepageData] = useState(null);
  const [view, setView] = useState('home');
  const [loading, setLoading] = useState(true);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [youtubeQuery, setYoutubeQuery] = useState('');
  const [settingsOpen, setSettingsOpen] = useState(false);

  // Playlist Modal State
  const [playlistModalOpen, setPlaylistModalOpen] = useState(false);
  const [songForPlaylist, setSongForPlaylist] = useState(null);

  useEffect(() => {
    loadSongs();
    loadHomepageData();

    // WebSocket for real-time updates
    const ws = new WebSocket(getWsUrl());

    ws.onopen = () => {
      console.log('Connected to notification server');
    };

    ws.onmessage = (event) => {
      if (event.data === 'library_updated') {
        console.log('Library update received, refreshing...');
        loadSongs();
      }
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    return () => {
      ws.close();
    };
  }, []);

  const loadSongs = async () => {
    try {
      const data = await getSongs();
      setSongs(data);
    } catch (error) {
      console.error("Error loading songs:", error);
    } finally {
      if (songs.length > 0) setLoading(false);
    }
  };

  const loadHomepageData = async () => {
    try {
      const data = await getHomepage();
      setHomepageData(data);
    } catch (error) {
      console.error("Error loading homepage:", error);
    } finally {
      setLoading(false);
    }
  };

  const handlePlaySong = async (song) => {
    setCurrentSong(song);
    const idx = songs.findIndex(s => s.id === song.id);
    if (idx >= 0) setCurrentIndex(idx);
    // Record play for history
    try {
      await recordPlay(song.id);
    } catch (err) {
      console.error('Failed to record play:', err);
    }
  };

  // Open Playlist Modal
  const handleAddToPlaylist = (song) => {
    setSongForPlaylist(song);
    setPlaylistModalOpen(true);
  };

  const handleNext = () => {
    if (songs.length === 0) return;
    const nextIdx = (currentIndex + 1) % songs.length;
    setCurrentIndex(nextIdx);
    setCurrentSong(songs[nextIdx]);
  };

  const handlePrev = () => {
    if (songs.length === 0) return;
    const prevIdx = currentIndex === 0 ? songs.length - 1 : currentIndex - 1;
    setCurrentIndex(prevIdx);
    setCurrentSong(songs[prevIdx]);
  };

  const handleUploadComplete = () => {
    loadSongs();
    setView('nowplaying');
  };

  const handleNavigate = (viewId, query = '') => {
    setView(viewId);
    if (query) setYoutubeQuery(query);
  };

  const navItems = [
    { id: 'home', label: 'Home', icon: '🏠' },
    { id: 'nowplaying', label: 'Now Playing' },
    { id: 'playlist', label: 'Library' }, // Keeping ID 'playlist' for Library view legacy, but label is Library
    { id: 'playlists', label: 'Playlists' }, // New Playlists view
    { id: 'youtube', label: 'YouTube', icon: '🎬' },
    { id: 'upload', label: 'Upload' },
  ];

  return (
    <div className="h-screen flex flex-col overflow-hidden">
      {/* Top Navigation */}
      <nav className="glass-dark border-b border-white/5 px-8 py-4 flex items-center justify-between z-50">
        <div className="flex items-center gap-8">
          <div className="flex items-center gap-3">
            <img src="/favicon.png" alt="Lazyio" className="w-8 h-8 rounded-lg" />
            <span className="text-xl font-bold bg-gradient-to-r from-pink-500 to-purple-500 bg-clip-text text-transparent">
              Lazyio
            </span>
          </div>
          <div className="flex items-center gap-6">
            {navItems.map(item => (
              <button
                key={item.id}
                onClick={() => handleNavigate(item.id)}
                className={`text-sm font-medium transition-all relative py-2
                  ${view === item.id
                    ? 'text-white'
                    : 'text-white/50 hover:text-white/80'
                  }`}
              >
                {item.label}
                {view === item.id && (
                  <span className="absolute bottom-0 left-0 right-0 h-0.5 bg-pink-500 rounded-full" />
                )}
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center gap-6">
          <SmartSearch songs={songs} onSelectSong={handlePlaySong} />

          <div
            className="w-10 h-10 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center cursor-pointer hover:opacity-90 transition shadow-lg shadow-pink-500/20"
            onClick={() => setSettingsOpen(true)}
          >
            <span className="text-sm font-medium">U</span>
          </div>
        </div>
      </nav>

      {/* Main Content Area - Stacked for persistence */}
      <div className="flex-1 flex flex-col overflow-hidden relative">
        {/* Pages that can be unmounted */}
        {view === 'home' && (
          <Home
            data={homepageData}
            onPlaySong={handlePlaySong}
            onNavigate={handleNavigate}
            onRefresh={loadHomepageData}
            onOpenPlaylistModal={handleAddToPlaylist}
          />
        )}
        {view === 'youtube' && <YouTube onDownloadComplete={handleUploadComplete} initialQuery={youtubeQuery} />}
        {view === 'upload' && <Upload onUploadComplete={handleUploadComplete} />}
        {view === 'playlists' && <Playlists onPlaySong={handlePlaySong} onNavigate={handleNavigate} onOpenPlaylistModal={handleAddToPlaylist} />}

        {view === 'playlist' && (
          <div className="h-full flex-1 overflow-y-auto p-8">
            <div className="max-w-4xl mx-auto">
              <h1 className="text-3xl font-bold mb-8 animate-fade-in">Your Library</h1>
              {loading ? (
                <div className="flex items-center justify-center py-20">
                  <div className="w-12 h-12 rounded-full border-4 border-pink-500/30 border-t-pink-500 animate-spin" />
                </div>
              ) : songs.length === 0 ? (
                <div className="text-center py-20 animate-fade-in">
                  <div className="w-24 h-24 mx-auto mb-6 rounded-full bg-white/5 flex items-center justify-center">
                    <svg className="w-12 h-12 text-white/20" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
                    </svg>
                  </div>
                  <p className="text-xl text-white/40 mb-4">No songs yet</p>
                  <button onClick={() => handleNavigate('upload')} className="btn-primary">
                    Upload Music
                  </button>
                </div>
              ) : (
                <div className="space-y-2">
                  {songs.map((song, index) => (
                    <div
                      key={song.id}
                      className={`group song-item flex items-center gap-4 p-4 rounded-xl cursor-pointer animate-fade-in
                        ${currentSong?.id === song.id ? 'bg-pink-500/10 border border-pink-500/20' : 'hover:bg-white/5'}`}
                      style={{ animationDelay: `${index * 0.05}s` }}
                      onClick={() => handlePlaySong(song)}
                    >
                      <div className="w-14 h-14 rounded-lg bg-gradient-to-br from-pink-500/20 to-purple-600/20 flex items-center justify-center flex-shrink-0 overflow-hidden">
                        {currentSong?.id === song.id ? (
                          <div className="flex items-end gap-0.5 h-5">
                            {[...Array(3)].map((_, i) => (
                              <div key={i} className="w-1 bg-pink-500 rounded-full visualizer-bar" style={{ animationDelay: `${i * 0.1}s` }} />
                            ))}
                          </div>
                        ) : (song.cover_art || song.thumbnail) ? (
                          <img src={song.cover_art || song.thumbnail} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <span className="text-white/40">{index + 1}</span>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold truncate">{song.title || "Unknown"}</p>
                        <p className="text-sm text-white/50 truncate">{song.artist || "Unknown Artist"}</p>
                      </div>

                      {/* Song Menu - visible on hover */}
                      {/* Song Menu - visible on hover */}
                      <SongMenu
                        className="opacity-0 group-hover:opacity-100 transition mr-2"
                        song={song}
                        onAddToPlaylist={handleAddToPlaylist}
                        onDelete={async (s) => {
                          try {
                            await deleteSong(s.id);
                            loadSongs(); // Refresh list via App's loadSongs
                          } catch (err) {
                            console.error("Failed to delete song:", err);
                          }
                        }}
                      />

                      <span className="text-sm text-white/40">{song.album || ""}</span>
                      <span className="text-sm text-white/40 w-16 text-right">
                        {song.duration ? `${Math.floor(song.duration / 60)}:${(song.duration % 60).toString().padStart(2, '0')}` : "—"}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Now Playing - handled by persistent player */}
      </div>

      {/* Persistent Player - Handles both Mini and Full views */}
      <Player
        currentSong={currentSong}
        onNext={handleNext}
        onPrev={handlePrev}
        playlist={songs}
        onSelectSong={handlePlaySong}
        fullView={view === 'nowplaying'}
        onToggleView={() => setView(v => v === 'nowplaying' ? 'home' : 'nowplaying')}
      />
      <SettingsModal open={settingsOpen} onClose={() => setSettingsOpen(false)} />

      {/* Global Modals */}
      <AddToPlaylistModal
        isOpen={playlistModalOpen}
        onClose={() => setPlaylistModalOpen(false)}
        song={songForPlaylist}
      />
    </div>
  );
}

export default App;
