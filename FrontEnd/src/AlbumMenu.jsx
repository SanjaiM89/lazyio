import React, { useState, useRef, useEffect } from 'react';

// Three-dot menu for an album: add the whole album to a playlist.
const AlbumMenu = ({ songIds = [], onAddAlbumToPlaylist, className = "", dropUp = false }) => {
    const [isOpen, setIsOpen] = useState(false);
    const menuRef = useRef(null);

    useEffect(() => {
        const handleClickOutside = (event) => {
            if (menuRef.current && !menuRef.current.contains(event.target)) {
                setIsOpen(false);
            }
        };

        if (isOpen) {
            document.addEventListener('mousedown', handleClickOutside);
        }
        return () => {
            document.removeEventListener('mousedown', handleClickOutside);
        };
    }, [isOpen]);

    const toggleMenu = (e) => {
        e.stopPropagation();
        setIsOpen(!isOpen);
    };

    const handleAdd = (e) => {
        e.stopPropagation();
        setIsOpen(false);
        onAddAlbumToPlaylist(songIds);
    };

    return (
        <div className={`relative ${className} ${isOpen ? '!opacity-100 z-50' : ''}`} ref={menuRef}>
            <button
                onClick={toggleMenu}
                className="p-2 rounded-full hover:bg-white/10 text-white/40 hover:text-white transition"
                title="Album options"
            >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z" />
                </svg>
            </button>

            {isOpen && (
                <div className={`absolute right-0 w-56 bg-[#1a1a2e]/60 backdrop-blur-md border border-white/10 rounded-xl shadow-xl z-50 overflow-hidden animate-fade-in ${dropUp ? 'bottom-full mb-1' : 'top-full mt-1'}`}>
                    <div className="py-1">
                        <button
                            onClick={handleAdd}
                            disabled={songIds.length === 0}
                            className="w-full text-left px-4 py-2.5 text-sm text-white hover:bg-white/10 flex items-center gap-3 group disabled:opacity-50"
                        >
                            <svg className="w-4 h-4 text-white/50 group-hover:text-pink-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" /></svg>
                            Add album to Playlist ({songIds.length})
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AlbumMenu;
