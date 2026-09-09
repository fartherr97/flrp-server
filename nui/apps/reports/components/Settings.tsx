import { useEffect, useRef, useState } from 'react';
import { Check, Settings as Gear } from 'lucide-react';
import { cn } from '@flrp/components';
import { notificationsEnabled, setNotificationsEnabled } from '../lib';

export function SettingsMenu() {
  const [open, setOpen] = useState(false);
  const [notifs, setNotifs] = useState(notificationsEnabled());
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const h = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    window.addEventListener('mousedown', h); return () => window.removeEventListener('mousedown', h);
  }, []);
  return (
    <div ref={ref} className="relative">
      <button className="v-btn v-btn-panel h-9 w-9 rounded px-0" onClick={() => setOpen((o) => !o)} aria-label="Settings"><Gear className="size-4" /></button>
      {open && (
        <div className="absolute right-0 top-[calc(100%+4px)] z-20 w-48 rounded-[8px] border-2 border-border bg-bg p-1 shadow-lg shadow-black/50 animate-flrp-in">
          <div className="px-2 py-1.5 text-center text-sm font-semibold">Settings</div>
          <div className="my-1 h-px bg-border" />
          <button className="flex w-full items-center gap-2 rounded-[4px] px-2 py-1.5 text-sm transition-colors hover:bg-panel"
            onClick={() => { const v = !notifs; setNotifs(v); setNotificationsEnabled(v); }}>
            <span className={cn('flex size-4 items-center justify-center', notifs ? 'opacity-100' : 'opacity-0')}><Check className="size-4 text-primary" /></span>
            Notifications
          </button>
        </div>
      )}
    </div>
  );
}
