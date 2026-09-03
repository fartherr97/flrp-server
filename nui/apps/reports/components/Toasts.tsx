import { useEffect, useState } from 'react';
import { useNuiEvent } from '@flrp/components';
import type { Toast } from '../types';
let idc = 0;
export function Toasts({ hintKey }: { hintKey: string }) {
  const [items, setItems] = useState<(Toast & { _id: number })[]>([]);
  useNuiEvent<Toast>('toast', (t) => {
    const _id = ++idc;
    setItems((x) => [...x.slice(-3), { ...t, _id }]);
    setTimeout(() => setItems((x) => x.filter((i) => i._id !== _id)), (t.seconds || 8) * 1000);
  });
  useEffect(() => { if (items.length > 4) setItems((x) => x.slice(-4)); }, [items]);
  const bar = (k?: string) => (k === 'new' ? 'bg-warning' : k === 'ok' ? 'bg-success' : k === 'error' || k === 'msg' ? 'bg-primary' : 'bg-primary');
  return (
    <div className="pointer-events-none absolute right-4 top-4 z-50 flex w-[330px] flex-col gap-2">
      {items.map((t) => (
        <div key={t._id} className="animate-flrp-slide overflow-hidden rounded-lg border border-border bg-elevated shadow-lg shadow-black/40">
          <div className="flex gap-2.5 p-3">
            <span className={`w-1 shrink-0 rounded ${bar(t.kind)}`} />
            <div className="min-w-0">
              <div className="text-[13px] font-bold">{t.title}</div>
              {t.body && <div className="mt-0.5 break-words text-xs text-fg-muted">{t.body}</div>}
              {t.reportId != null && <div className="mt-1 text-2xs text-fg-faint">Press <kbd className="rounded border border-border bg-panel-hover px-1 font-bold text-fg-muted">{hintKey}</kbd> to open</div>}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
