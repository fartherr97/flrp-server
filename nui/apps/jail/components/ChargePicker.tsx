import { useMemo, useState } from 'react';
import { Search, X, RotateCcw } from 'lucide-react';
import type { Charge, JailPlayer } from '../types';

const fmt = (s: number) => (s <= 0 ? 'No jail' : s < 60 ? `${s}s` : `${Math.floor(s / 60)}m${s % 60 ? ' ' + (s % 60) + 's' : ''}`);

function category(cls = ''): string {
  const d = cls.toLowerCase();
  if (d.includes('capital') || d.includes('life')) return 'Capital/Life';
  if (d.includes('felony')) return 'Felony';
  if (d.includes('misdemean')) return 'Misdemeanor';
  if (d.includes('infraction')) return 'Infraction';
  return 'Other';
}
const TONE: Record<string, string> = {
  'Capital/Life': 'bg-danger/20 text-danger',
  Felony: 'bg-danger/15 text-danger',
  Misdemeanor: 'bg-warning/15 text-warning',
  Infraction: 'bg-info/15 text-info',
  Other: 'bg-panel-hover text-fg-muted',
};
const FILTERS = ['All', 'Infraction', 'Misdemeanor', 'Felony', 'Capital/Life'];

export function ChargePicker({ player, charges, current, max, onPick, onReset, onClose }:
  { player: JailPlayer; charges: Charge[]; current: number; max: number;
    onPick: (c: Charge) => void; onReset: () => void; onClose: () => void }) {
  const [q, setQ] = useState('');
  const [deg, setDeg] = useState('All');

  const rows = useMemo(() => {
    const query = q.trim().toLowerCase();
    return charges.filter((c) => {
      if (deg !== 'All' && category(c.class) !== deg) return false;
      if (!query) return true;
      return c.name.toLowerCase().includes(query)
        || (c.code || '').toLowerCase().includes(query)
        || (c.class || '').toLowerCase().includes(query);
    });
  }, [charges, q, deg]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6" onMouseDown={onClose}>
      <div className="flex max-h-[82vh] w-full max-w-[720px] flex-col overflow-hidden rounded-lg border border-border bg-bg shadow-2xl animate-flrp-rise"
        onMouseDown={(e) => e.stopPropagation()}>

        {/* header */}
        <div className="flex items-center gap-3 border-b border-border-soft px-5 py-3">
          <div className="min-w-0">
            <div className="text-[15px] font-bold">Add Charges</div>
            <div className="truncate text-xs text-fg-muted">{player.name} — total <b className="tabular-nums text-fg">{fmt(current)}</b></div>
          </div>
          <div className="ml-auto flex items-center gap-2">
            <button onClick={onReset} title="Reset the seconds box"
              className="inline-flex items-center gap-1.5 rounded-sm bg-panel-hover px-2.5 py-1.5 text-xs font-semibold text-fg-muted hover:text-fg [&_svg]:size-3.5"><RotateCcw />Reset</button>
            <button onClick={onClose}
              className="inline-flex items-center gap-1.5 rounded-sm bg-panel-hover px-2.5 py-1.5 text-xs font-semibold text-fg-muted hover:text-fg [&_svg]:size-3.5"><X />Done</button>
          </div>
        </div>

        {/* search + degree filter */}
        <div className="space-y-2.5 px-5 pt-3.5">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-fg-faint" />
            <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search charge, statute code, or degree…"
              className="w-full rounded-sm border border-border bg-panel py-2.5 pl-9 pr-3 text-sm text-fg placeholder:text-fg-faint focus:border-primary focus:outline-none" />
          </div>
          <div className="flex flex-wrap gap-1.5">
            {FILTERS.map((f) => (
              <button key={f} onClick={() => setDeg(f)}
                className={`rounded-full px-3 py-1 text-2xs font-bold ${deg === f ? 'bg-primary text-primary-fg' : 'bg-panel-hover text-fg-muted hover:text-fg'}`}>{f}</button>
            ))}
            <span className="ml-auto self-center text-2xs text-fg-faint">{rows.length} charge{rows.length === 1 ? '' : 's'}</span>
          </div>
        </div>

        {/* list */}
        <div className="mt-2 flex-1 overflow-y-auto px-3 pb-3">
          {rows.length === 0
            ? <div className="py-10 text-center text-sm text-fg-faint">No charges match.</div>
            : rows.map((c) => {
              const cat = category(c.class);
              return (
                <button key={c.id} onClick={() => onPick(c)}
                  className="flex w-full items-center gap-3 rounded-sm px-2 py-2 text-left hover:bg-panel-hover">
                  <span className="w-16 shrink-0 font-mono text-2xs text-fg-faint">{c.code || '—'}</span>
                  <span className="min-w-0 flex-1 truncate text-[13px] font-semibold" title={c.name}>{c.name}</span>
                  <span className={`shrink-0 rounded px-1.5 py-0.5 text-2xs font-bold ${TONE[cat]}`}>{cat}</span>
                  <span className="w-16 shrink-0 text-right text-xs font-bold tabular-nums text-fg-muted">{fmt(c.jailSeconds)}</span>
                </button>
              );
            })}
        </div>

        <div className="border-t border-border-soft px-5 py-2 text-2xs text-fg-faint">
          Click a charge to add its jail time. Adding stacks; the total fills the seconds box (max {max}s). <b className="text-fg-muted">Reset</b> clears it.
        </div>
      </div>
    </div>
  );
}
