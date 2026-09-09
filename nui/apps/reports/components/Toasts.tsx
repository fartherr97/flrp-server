import { useState } from 'react';
import { useNuiEvent } from '@flrp/components';
import { BadgeAlert, CheckCircle2, MessageSquare, ShieldAlert } from 'lucide-react';
import type { Toast } from '../types';
import { notificationsEnabled } from '../lib';
let idc = 0;
export function Toasts({ hintKey }: { hintKey: string }) {
  const [items, setItems] = useState<(Toast & { _id: number })[]>([]);
  useNuiEvent<Toast>('toast', (t) => {
    if (!notificationsEnabled()) return;
    const _id = ++idc;
    setItems((x) => [...x.slice(-3), { ...t, _id }]);
    setTimeout(() => setItems((x) => x.filter((i) => i._id !== _id)), (t.seconds || 8) * 1000);
  });
  const icon = (k?: string) =>
    k === 'new' ? <ShieldAlert className="size-4 text-primary" /> :
    k === 'ok' ? <CheckCircle2 className="size-4 text-success" /> :
    k === 'msg' ? <MessageSquare className="size-4 text-primary" /> :
    k === 'error' ? <BadgeAlert className="size-4 text-danger" /> : <CheckCircle2 className="size-4 text-success" />;
  return (
    <div className="pointer-events-none absolute right-4 top-4 z-[60] flex w-[340px] flex-col gap-2">
      {items.map((t) => (
        <div key={t._id} className="animate-flrp-slide rounded-[8px] border-2 border-border bg-bg p-3 shadow-lg shadow-black/50">
          <div className="flex items-start gap-2.5">
            <span className="mt-0.5 shrink-0">{icon(t.kind)}</span>
            <div className="min-w-0">
              <div className="text-sm font-semibold">{t.title}</div>
              {t.body && <div className="mt-0.5 break-words text-xs text-fg-muted">{t.body}</div>}
              {t.reportId != null && <div className="mt-1.5 text-xs text-fg-faint">Press <kbd className="rounded-[2px] border border-border bg-panel px-1 font-bold text-fg-muted">{hintKey}</kbd> to open</div>}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
