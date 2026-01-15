import React from 'react';

const Modal = ({ open, onClose, children }) => {
    if (!open) return null;

    return (
        <div
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
            onClick={onClose}
        >
            {/* Backdrop */}
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />

            {/* Modal Content */}
            <div
                className="relative glass rounded-2xl max-w-md w-full animate-scale-in"
                onClick={e => e.stopPropagation()}
            >
                {children}
            </div>
        </div>
    );
};

Modal.Title = ({ children }) => (
    <div className="p-6 pb-2">
        <h3 className="text-xl font-semibold">{children}</h3>
    </div>
);

Modal.Body = ({ children }) => (
    <div className="px-6 py-4 text-white/70">
        {children}
    </div>
);

Modal.Actions = ({ children }) => (
    <div className="flex justify-end gap-3 p-6 pt-2">
        {children}
    </div>
);

// Confirm Modal Preset
export const ConfirmModal = ({
    open,
    title,
    message,
    confirmText = "Confirm",
    cancelText = "Cancel",
    onConfirm,
    onCancel,
    danger = false
}) => (
    <Modal open={open} onClose={onCancel}>
        <Modal.Title>{title}</Modal.Title>
        <Modal.Body>{message}</Modal.Body>
        <Modal.Actions>
            <button
                onClick={onCancel}
                className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 transition"
            >
                {cancelText}
            </button>
            <button
                onClick={onConfirm}
                className={`px-4 py-2 rounded-xl transition ${danger
                        ? 'bg-red-500 hover:bg-red-600'
                        : 'bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90'
                    }`}
            >
                {confirmText}
            </button>
        </Modal.Actions>
    </Modal>
);

// Input Modal Preset
export const InputModal = ({
    open,
    title,
    placeholder = "Enter text...",
    confirmText = "Create",
    onConfirm,
    onCancel
}) => {
    const [value, setValue] = React.useState('');

    React.useEffect(() => {
        if (open) setValue('');
    }, [open]);

    const handleConfirm = () => {
        if (value.trim()) {
            onConfirm(value.trim());
        }
    };

    return (
        <Modal open={open} onClose={onCancel}>
            <Modal.Title>{title}</Modal.Title>
            <div className="px-6 py-4">
                <input
                    type="text"
                    value={value}
                    onChange={e => setValue(e.target.value)}
                    placeholder={placeholder}
                    className="w-full bg-white/5 border border-white/10 rounded-xl py-3 px-4 text-white placeholder-white/30 focus:outline-none focus:border-pink-500/50 transition"
                    autoFocus
                    onKeyDown={e => e.key === 'Enter' && handleConfirm()}
                />
            </div>
            <Modal.Actions>
                <button
                    onClick={onCancel}
                    className="px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 transition"
                >
                    Cancel
                </button>
                <button
                    onClick={handleConfirm}
                    disabled={!value.trim()}
                    className="px-4 py-2 rounded-xl bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90 transition disabled:opacity-50"
                >
                    {confirmText}
                </button>
            </Modal.Actions>
        </Modal>
    );
};

export default Modal;
