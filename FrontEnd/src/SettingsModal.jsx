import React, { useState, useEffect, useRef } from 'react';
import Modal from './Modal';
import api from './api';

const SettingsModal = ({ open, onClose }) => {
    const [ip, setIp] = useState('localhost');
    const [port, setPort] = useState('8000');
    const [cookiesStatus, setCookiesStatus] = useState(null);
    const [uploading, setUploading] = useState(false);
    const fileInputRef = useRef(null);

    useEffect(() => {
        if (open) {
            const savedIp = localStorage.getItem('backend_ip') || 'localhost';
            const savedPort = localStorage.getItem('backend_port') || '8000';
            setIp(savedIp);
            setPort(savedPort);
            checkCookiesStatus();
        }
    }, [open]);

    const checkCookiesStatus = async () => {
        try {
            const res = await api.get('/settings/cookies');
            setCookiesStatus(res.data);
        } catch (err) {
            console.error('Failed to check cookies status:', err);
            setCookiesStatus({ exists: false });
        }
    };

    const handleCookiesUpload = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setUploading(true);
        const formData = new FormData();
        formData.append('file', file);

        try {
            await api.post('/settings/cookies', formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });
            alert('Cookies uploaded successfully!');
            checkCookiesStatus();
        } catch (err) {
            alert('Failed to upload cookies: ' + (err.response?.data?.detail || err.message));
        } finally {
            setUploading(false);
            if (fileInputRef.current) fileInputRef.current.value = '';
        }
    };

    const handleDeleteCookies = async () => {
        try {
            await api.delete('/settings/cookies');
            setCookiesStatus({ exists: false });
        } catch (err) {
            alert('Failed to delete cookies');
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

                {/* YouTube Cookies */}
                <div className="space-y-4">
                    <h3 className="text-sm font-semibold text-white/70 uppercase tracking-wider">YouTube Cookies</h3>
                    <div className="bg-yellow-500/10 border border-yellow-500/20 text-yellow-200 text-sm p-3 rounded-xl">
                        <p>Upload cookies.txt to bypass YouTube bot detection on hosted servers.</p>
                        <p className="opacity-70 mt-1">Export using browser extension: "Get cookies.txt LOCALLY"</p>
                    </div>

                    {cookiesStatus?.exists ? (
                        <div className="flex items-center justify-between p-3 bg-green-500/10 border border-green-500/20 rounded-xl">
                            <div>
                                <p className="text-green-400 text-sm font-medium">✓ Cookies uploaded</p>
                                <p className="text-white/50 text-xs">Updated: {new Date(cookiesStatus.updated_at).toLocaleString()}</p>
                            </div>
                            <button
                                onClick={handleDeleteCookies}
                                className="px-3 py-1 text-xs bg-red-500/20 text-red-400 rounded-lg hover:bg-red-500/30 transition"
                            >
                                Delete
                            </button>
                        </div>
                    ) : (
                        <div className="flex items-center justify-between p-3 bg-white/5 border border-white/10 rounded-xl">
                            <p className="text-white/50 text-sm">No cookies file uploaded</p>
                            <label className="px-3 py-1 text-xs bg-pink-500/20 text-pink-400 rounded-lg hover:bg-pink-500/30 transition cursor-pointer">
                                {uploading ? 'Uploading...' : 'Upload'}
                                <input
                                    ref={fileInputRef}
                                    type="file"
                                    accept=".txt"
                                    onChange={handleCookiesUpload}
                                    className="hidden"
                                    disabled={uploading}
                                />
                            </label>
                        </div>
                    )}
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
