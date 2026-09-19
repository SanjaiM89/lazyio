import React, { useEffect, useState } from 'react';
import { getPlaylists, addSongToPlaylist, createPlaylist } from '../api';
import { Icon } from './ui';

export function AddToPlaylistModal({ open, onClose, song, songIds }) {
  const [playlists, setPlaylists] = useState([]);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!open) return;
    (async () => { try { setPlaylists((await getPlaylists(1, 50)).playlists || []); } catch (e) { console.error(e); } })();
  }, [open ]);
  if (!open) return null;
  const ids = songIds || (song ? [song.id] : []);
  const add = async (pid) => {
    setBusy(true);
    try { for (const id of ids) await addSongToPlaylist(pid, id); onClose(); }
    catch (e) { console.error(e); } finally { setBusy(false); }
  };
  const create = async () => {
    if (!name.trim()) return;
    setBusy(true);
    try {
      const p = await createPlaylist(name.trim());
      for (const id of ids) await addSongToPlaylist(p.id, id);
      setName(''); onClose();
    } catch (e) { console.error(e); } finally { setBusy(false); }
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={onClose}>
      <div className="w-full max-w-sm rounded-2xl bg-surface-container-high border border-white/10 p-5" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-1">
          <h3 className="font-headline-sm text-headline-sm">Add to playlist</h3>
          <button onClick={onClose} className="text-outline hover:text-on-surface" type="button"><Icon name="close" size={18} /></button>
        </div>
        <p className="font-body-sm text-body-sm text-on-surface-variant mb-4 truncate">{song?.title || `${ids.length} track(s)`}</p>
        <div className="max-h-56 overflow-y-auto space-y-1 mb-4">
          {playlists.map((p) => (
            <button key={p.id} disabled={busy} onClick={() => add(p.id)} className="w-full flex items-center gap-3 p-2.5 rounded-xl hover:bg-surface-container-highest/60 transition text-left disabled:opacity-50" type="button">
              <span className="w-9 h-9 rounded-lg bg-surface-container-highest flex items-center justify-center text-primary"><Icon name="queue_music" size={18} /></span>
              <span className="font-label-md text-label-md truncate">{p.name}</span>
            </button>
          ))}
          {playlists.length === 0 && <p className="font-body-sm text-body-sm text-outline text-center py-4">No playlists yet — create one below.</p>}
        </div>
        <div className="flex gap-2">
          <input value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && create()} placeholder="New playlist…" className="flex-1 h-10 px-4 rounded-full bg-surface-container-lowest font-body-md text-body-md placeholder:text-outline focus:outline-none" />
          <button onClick={create} disabled={busy} className="h-10 px-4 rounded-full bg-primary-container text-on-primary-container font-label-md disabled:opacity-50" type="button">Create</button>
        </div>
      </div>
    </div>
  );
}

export function SongMenu({ song, onAdd, onDelete, onPlayNext }) {
  const [open, setOpen] = useState(false);
  return (
    <span className="relative" onClick={(e) => e.stopPropagation()}>
      <button onClick={() => setOpen(!open)} className="text-outline hover:text-on-surface" type="button"><Icon name="more_horiz" size={18} /></button>
      {open && (
        <>
          <span className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <span className="absolute right-0 top-7 z-50 w-48 rounded-xl bg-surface-container-highest border border-white/10 p-1.5 flex flex-col shadow-2xl">
            {onPlayNext && <MenuItem icon="playlist_add" label="Play next" onClick={() => { onPlayNext(song); setOpen(false); }} />}
            <MenuItem icon="playlist_add" label="Add to playlist" onClick={() => { onAdd(song); setOpen(false); }} />
            {onDelete && <MenuItem icon="delete" label="Delete" danger onClick={() => { onDelete(song); setOpen(false); }} />}
          </span>
        </>
      )}
    </span>
  );
}

function MenuItem({ icon, label, onClick, danger }) {
  return (
    <button onClick={onClick} className={`flex items-center gap-2.5 px-3 py-2 rounded-lg font-label-md text-label-md transition text-left ${danger ? 'text-error hover:bg-error-container/40' : 'text-on-surface hover:bg-white/10'}`} type="button">
      <Icon name={icon} size={16} /> {label}
    </button>
  );
}

export function SettingsModal({ open, onClose }) {
  const [ip, setIp] = useState(localStorage.getItem('backend_ip') || 'localhost');
  const [port, setPort] = useState(localStorage.getItem('backend_port') || '8000');
  if (!open) return null;
  const save = () => { localStorage.setItem('backend_ip', ip.trim() || 'localhost'); localStorage.setItem('backend_port', port.trim() || '8000'); window.location.reload(); };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={onClose}>
      <div className="w-full max-w-sm rounded-2xl bg-surface-container-high border border-white/10 p-5" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-headline-sm text-headline-sm">Backend settings</h3>
          <button onClick={onClose} className="text-outline hover:text-on-surface" type="button"><Icon name="close" size={18} /></button>
        </div>
        <label className="font-label-sm text-label-sm uppercase tracking-wider text-outline block mb-1">Host</label>
        <input value={ip} onChange={(e) => setIp(e.target.value)} className="w-full h-10 px-4 rounded-xl bg-surface-container-lowest font-body-md mb-3 focus:outline-none" />
        <label className="font-label-sm text-label-sm uppercase tracking-wider text-outline block mb-1">Port</label>
        <input value={port} onChange={(e) => setPort(e.target.value)} className="w-full h-10 px-4 rounded-xl bg-surface-container-lowest font-body-md mb-4 focus:outline-none" />
        <button onClick={save} className="w-full h-10 rounded-full bg-primary-container text-on-primary-container font-label-lg" type="button">Save & reconnect</button>
      </div>
    </div>
  );
}

/* Full-screen immersive player lives in NocturnePlayer.jsx. */
