import { useEffect, useRef, useState } from 'react';
import { Check, ChevronsUpDown } from 'lucide-react';
import { cn } from '@flrp/components';
import { VModal } from './VModal';
import { req } from '../lib';
import type { State } from '../types';

function CategorySelect({ state, value, onChange }: { state: State; value: string; onChange: (id: string) => void }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const h = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    window.addEventListener('mousedown', h); return () => window.removeEventListener('mousedown', h);
  }, []);
  const cur = state.categories.find((c) => c.id === value);
  return (
    <div ref={ref} className="relative">
      <button type="button" onClick={() => setOpen((o) => !o)} className="v-btn h-10 w-full justify-between rounded px-3 font-medium">
        <span className="inline-flex items-center gap-2"><span className="size-2 rounded-full" style={{ background: cur?.colour }} />{cur?.label || 'Select a category…'}</span>
        <ChevronsUpDown className="size-4 opacity-50" />
      </button>
      {open && (
        <div className="absolute left-0 top-[calc(100%+4px)] z-10 w-full rounded-[8px] border-2 border-border bg-bg p-1 shadow-lg shadow-black/50 animate-flrp-in">
          {state.categories.map((c) => (
            <button type="button" key={c.id} onClick={() => { onChange(c.id); setOpen(false); }}
              className={cn('flex w-full items-center gap-2 rounded-[4px] px-2 py-1.5 text-left text-sm transition-colors hover:bg-panel', value === c.id && 'text-fg')}>
              <Check className={cn('size-4', value === c.id ? 'opacity-100 text-primary' : 'opacity-0')} />
              <span className="size-2 rounded-full" style={{ background: c.colour }} />{c.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

export function NewReport({ state, open, onClose, onDone, logo }:
  { state: State; open: boolean; onClose: () => void; onDone: (s: State, id: number) => void; logo: React.ReactNode }) {
  const [cat, setCat] = useState(state.categories[0]?.id || 'other');
  const [target, setTarget] = useState('');
  const [desc, setDesc] = useState('');
  const [nearby, setNearby] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const reset = () => { setDesc(''); setTarget(''); setNearby(false); setCat(state.categories[0]?.id || 'other'); setError(null); };
  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return; setBusy(true);
    const r = await req<any>('submit', { category: cat, target, description: desc, nearby });
    setBusy(false);
    if (!r.ok) return setError(r.error || 'Failed.');
    const s = await req<State>('state');
    reset();
    if (s.ok) onDone(s, r.id);
  };
  return (
    <VModal open={open} onClose={onClose} title="Report Menu" icon={logo} width="w-[540px]" surface="bg-elevated">
      <form onSubmit={submit} className="grid grid-cols-2 gap-4">
        {error && <div className="col-span-2 rounded border-2 border-danger/40 bg-danger/10 px-3 py-2 text-sm font-medium text-danger">{error}</div>}
        <input className="v-input h-10" value={target} maxLength={100} onChange={(e) => setTarget(e.target.value)} placeholder="Player involved (name or ID, optional)" />
        <CategorySelect state={state} value={cat} onChange={setCat} />
        <div className="col-span-2">
          <textarea className="v-input min-h-[120px] resize-none py-2 leading-relaxed" value={desc} maxLength={state.maxDesc} required
            onChange={(e) => setDesc(e.target.value)} placeholder="Description… be specific: what, where, when. Include IDs if you can." />
          <div className="mt-1 text-right text-xs tabular-nums text-fg-faint">{desc.length} / {state.maxDesc}</div>
        </div>
        <label className="col-span-2 flex cursor-pointer items-center gap-3 rounded-[8px] border-2 border-border p-2 transition-all hover:border-primary">
          <span className={cn('flex size-4 shrink-0 items-center justify-center rounded-sm border border-primary transition-colors', nearby && 'bg-primary text-primary-fg')}>
            {nearby && <Check className="size-3.5" />}
          </span>
          <input type="checkbox" className="sr-only" checked={nearby} onChange={(e) => setNearby(e.target.checked)} />
          <span className="grid gap-[2px] leading-none">
            <span className="text-sm font-medium">Send players near you?</span>
            <span className="text-xs text-fg-muted">Attaches a list of every player within {state.nearbyDistance || 20}m to the report details.</span>
          </span>
        </label>
        <button type="submit" disabled={busy} className="v-btn col-span-2 rounded-[2px] font-bold">Submit Report</button>
        <div className="col-span-2 -mt-2 text-center text-xs text-fg-faint">
          Staff online now: <b className="text-fg">{state.staffOnline}</b> · up to {state.maxOpen || 1} open report{(state.maxOpen || 1) === 1 ? '' : 's'} at a time
        </div>
      </form>
    </VModal>
  );
}
