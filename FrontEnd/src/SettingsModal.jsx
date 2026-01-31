import React, { useState, useEffect } from 'react';
import Modal from './Modal';

const SettingsModal = ({ open, onClose }) => {
    const [ip, setIp] = useState('localhost');
    const [port, setPort] = useState('8000');

    useEffect(() => {
        if (open) {
            const savedIp = localStorage.getItem('backend_ip') || 'localhost';
            const savedPort = localStorage.getItem('backend_port') || '8000';
            setIp(savedIp);
            setPort(savedPort);
        }
    }, [open]);

    const handleSave = () => {
        localStorage.setItem('backend_ip', ip);
        localStorage.setItem('backend_port', port);
        // Reload to apply changes
        window.location.reload();
    };

    return (
        <Modal open={open} onClose={onClose}>
            <Modal.Title>Connection Settings</Modal.Title>
            <div className="px-6 py-4 space-y-4">
                <div>
                    <label className="block text-sm font-medium text-white/60 mb-1">Backend IP Address</label>
                    <input
                        type="text"
                        value={ip}
                        onChange={(e) => setIp(e.target.value)}
                        placeholder="localhost"
                        className="w-full bg-white/5 border border-white/10 rounded-xl py-2 px-4 text-white placeholder-white/30 focus:outline-none focus:border-pink-500/50 transition"
                    />
                </div>
                <div>
                    <label className="block text-sm font-medium text-white/60 mb-1">Backend Port</label>
                    <input
                        type="text"
                        value={port}
                        onChange={(e) => setPort(e.target.value)}
                        placeholder="8000"
                        className="w-full bg-white/5 border border-white/10 rounded-xl py-2 px-4 text-white placeholder-white/30 focus:outline-none focus:border-pink-500/50 transition"
                    />
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
