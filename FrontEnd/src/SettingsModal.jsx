import React, { useState, useEffect } from 'react';
import Modal from './Modal';
import { getTelegramStatus, scanTelegramChannel } from './api';

const SettingsModal = ({ open, onClose }) => {
    const [ip, setIp] = useState('localhost');
    const [port, setPort] = useState('8000');
    const [tgStatus, setTgStatus] = useState(null);
    const [scanning, setScanning] = useState(false);

    useEffect(() => {
        if (open) {
            const savedIp = localStorage.getItem('backend_ip') || 'localhost';
            const savedPort = localStorage.getItem('backend_port') || '8000';
            setIp(savedIp);
            setPort(savedPort);
            getTelegramStatus().then(setTgStatus).catch(() => setTgStatus(null));
        }
    }, [open]);

    const handleRescan = async () => {
        setScanning(true);
        try {
            const res = await scanTelegramChannel(false);
            alert(`Scan complete: ${res.added} new, ${res.scanned} scanned.`);
            setTgStatus(await getTelegramStatus());
        } catch (err) {
            alert('Rescan failed: ' + (err.response?.data?.detail || err.message));
        } finally {
            setScanning(false);
        }
    };

    const handleSave = () => {
        localStorage.setItem('backend_ip', ip);
        localStorage.setItem('backend_port', port);
        // Reload to apply changes
        window.location.reload();
    };

    return (
        <Modal open={open} onClose={onClose}>
            <Modal.Title>Settings</Modal.Title>
            <div className="px-6 py-4 space-y-6">
                {/* Connection Settings */}
                <div className="space-y-4">
                    <h3 className="text-sm font-semibold text-white/70 uppercase tracking-wider">Connection</h3>
                    <div className="bg-blue-500/10 border border-blue-500/20 text-blue-200 text-sm p-3 rounded-xl">
                        <p className="opacity-70">Enter backend URL (e.g., https://myapp.onrender.com) or IP:Port.</p>
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-white/60 mb-1">Server Address</label>
                        <input
                            type="text"
                            value={ip}
                            onChange={(e) => setIp(e.target.value)}
                            placeholder="localhost or https://myapp.com"
                            className="w-full bg-white/5 border border-white/10 rounded-xl py-2 px-4 text-white placeholder-white/30 focus:outline-none focus:border-pink-500/50 transition"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-white/60 mb-1">Port (Optional)</label>
                        <input
                            type="text"
                            value={port}
                            onChange={(e) => setPort(e.target.value)}
                            placeholder="8000"
                            className="w-full bg-white/5 border border-white/10 rounded-xl py-2 px-4 text-white placeholder-white/30 focus:outline-none focus:border-pink-500/50 transition"
                        />
                    </div>
                </div>

                {/* Telegram source channel */}
                <div className="space-y-4">
                    <h3 className="text-sm font-semibold text-white/70 uppercase tracking-wider">Telegram Library</h3>
                    <div className="bg-purple-500/10 border border-purple-500/20 text-purple-200 text-sm p-3 rounded-xl">
                        <p>Music is indexed from the Telegram source channel configured on the backend (.env).</p>
                        {tgStatus && (
                            <p className="opacity-70 mt-1">
                                Channel: {tgStatus.channel || 'not configured'}
                                {tgStatus.state?.last_scan_at
                                    ? ` • last scan ${new Date(tgStatus.state.last_scan_at * 1000).toLocaleString()}`
                                    : ''}
                            </p>
                        )}
                    </div>
                    <button
                        onClick={handleRescan}
                        disabled={scanning}
                        className="px-4 py-2 rounded-xl bg-purple-500/20 text-purple-200 hover:bg-purple-500/30 transition disabled:opacity-50 text-sm"
                    >
                        {scanning ? 'Scanning...' : 'Rescan Telegram channel'}
                    </button>
                </div>
            </div>
            <Modal.Actions>
                <button
                    onClick={onClose}
                    className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 transition"
                >
                    Cancel
                </button>
                <button
                    onClick={handleSave}
                    className="px-4 py-2 rounded-xl bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90 transition"
                >
                    Save & Reload
                </button>
            </Modal.Actions>
        </Modal>
    );
};

export default SettingsModal;
