import React from 'react';

export const Icon = ({ name, size = 18, className = '', fill = false }) => (
  <span
    className={`material-symbols-outlined ${fill ? 'icon-fill' : ''} ${className}`}
    style={{ fontSize: size }}
  >
    {name}
  </span>
);

export const fmtTime = (s) => {
  if (s == null || isNaN(s)) return '—';
  const m = Math.floor(s / 60);
  const sec = Math.floor(s % 60);
  return `${m}:${sec.toString().padStart(2, '0')}`;
};

export const Cover = ({ src, size = 'w-9 h-9', rounded = 'rounded-md', icon = 'music_note' }) => {
  if (src) return <img src={src} alt="" className={`${size} ${rounded} object-cover flex-shrink-0 bg-surface-container-highest`} />;
  return (
    <div className={`${size} ${rounded} bg-surface-container-highest flex-shrink-0 flex items-center justify-center text-outline`}>
      <Icon name={icon} size={16} />
    </div>
  );
};

export const Badge = ({ children, tone = 'default' }) => {
  const tones = {
    default: 'bg-surface-container-highest/60 text-outline',
    lossless: 'bg-surface-container-highest/60 text-primary font-bold tracking-widest',
    hires: 'bg-surface-container-highest/60 text-outline font-semibold tracking-widest',
    pill: 'bg-white/[0.08] backdrop-blur-md text-on-surface',
  };
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded font-label-sm text-label-sm uppercase ${tones[tone]}`}>
      {children}
    </span>
  );
};

export const SectionLabel = ({ children }) => (
  <span className="px-space-sm font-label-sm text-label-sm uppercase tracking-wider text-outline">{children}</span>
);

export const EmptyState = ({ icon = 'music_note', title, hint, action }) => (
  <div className="text-center py-16 animate-fade-up">
    <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-surface-container flex items-center justify-center text-outline">
      <Icon name={icon} size={28} />
    </div>
    <p className="font-headline-sm text-headline-sm text-on-surface mb-1">{title}</p>
    {hint && <p className="font-body-sm text-body-sm text-outline mb-4">{hint}</p>}
    {action}
  </div>
);
