import React from 'react';
import { Icon } from './ui';

export default function Header({ view, onNavigate, onBack, onForward }) {
  const tabs = [
    { id: 'home', label: 'Listen Now' },
    { id: 'albums-grid', label: 'Browse' },
    { id: 'videos', label: 'Videos' },
  ];
  return (
    <header className="fixed top-0 left-64 right-80 h-16 bg-surface/80 backdrop-blur-xl z-20 flex items-center justify-between px-margin">
      <div className="flex items-center gap-space-md">
        <div className="flex items-center gap-1">
          <button onClick={onBack} className="w-8 h-8 rounded-full flex items-center justify-center text-outline hover:text-on-surface hover:bg-surface-container-high transition-colors" type="button">
            <Icon name="chevron_left" size={18} />
          </button>
          <button onClick={onForward} className="w-8 h-8 rounded-full flex items-center justify-center text-outline hover:text-on-surface hover:bg-surface-container-high transition-colors" type="button">
            <Icon name="chevron_right" size={18} />
          </button>
        </div>
        <nav className="flex items-center gap-space-lg">
          {tabs.map((t) => (
            <button
              key={t.id}
              onClick={() => onNavigate(t.id)}
              className={`transition-colors ${view === t.id || (t.id === 'albums-grid' && view === 'albums') ? 'text-on-surface font-semibold' : 'font-label-md text-label-md text-on-surface-variant hover:text-on-surface'}`}
            >
              {t.label}
            </button>
          ))}
        </nav>
      </div>
      <div className="flex items-center gap-space-md">
        <div className="flex items-center gap-space-xs">
          <button className="w-8 h-8 rounded-full flex items-center justify-center text-outline hover:text-on-surface hover:bg-surface-container-high transition-colors" type="button">
            <Icon name="cast" size={20} />
          </button>
          <button className="w-8 h-8 rounded-full flex items-center justify-center text-outline hover:text-on-surface hover:bg-surface-container-high transition-colors" type="button">
            <Icon name="notifications" size={20} />
          </button>
        </div>
        <button onClick={() => onNavigate('settings')} className="w-8 h-8 rounded-full bg-primary flex items-center justify-center" type="button">
          <Icon name="person" size={18} className="text-on-primary" />
        </button>
      </div>
    </header>
  );
}
