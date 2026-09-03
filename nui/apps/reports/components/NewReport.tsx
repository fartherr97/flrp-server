import { useState } from 'react';
import { Send } from 'lucide-react';
import { Button, Input, Textarea, Field } from '@flrp/components';
import { req } from '../lib';
import type { State } from '../types';
export function NewReport({ state, onDone }: { state: State; onDone: (s: State) => void }) {
  const [cat, setCat] = useState(state.categories[0]?.id || 'other');
  const [target, setTarget] = useState('');
  const [desc, setDesc] = useState('');
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const submit = async () => {
    if (busy) return; setBusy(true);
    const r = await req<any>('submit', { category: cat, target, description: desc });
    setBusy(false);
    if (!r.ok) return setNotice({ ok: false, text: r.error || 'Failed.' });
    setDesc(''); setTarget(''); setCat(state.categories[0]?.id || 'other');
    const s = await req<State>('state'); if (s.ok) onDone(s);
    setNotice({ ok: true, text: `Report #${r.id} submitted — staff have been notified.` });
  };
  return (
    <div className="mx-auto max-w-[620px] space-y-4 py-1">
      <div>
        <h2 className="text-lg font-bold">Submit a report</h2>
        <p className="mt-0.5 text-[13px] text-fg-muted">Staff online now: <b className="text-fg">{state.staffOnline}</b>. You'll get a notification when someone claims it and can chat with them from <b>My Reports</b>.</p>
      </div>
      {notice && <div className={`rounded-sm px-3 py-2 text-[13px] font-medium ${notice.ok ? 'bg-success/15 text-success' : 'bg-danger/15 text-danger'}`}>{notice.text}</div>}
      <Field label="Category">
        <div className="flex flex-wrap gap-2">
          {state.categories.map((c) => (
            <button key={c.id} onClick={() => setCat(c.id)}
              className={`inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-[13px] font-semibold transition-colors ${cat === c.id ? 'border-primary/40 bg-primary/15 text-fg' : 'border-border bg-panel text-fg-muted hover:text-fg'}`}>
              <span className="size-2 rounded-full" style={{ background: c.colour }} />{c.label}
            </button>
          ))}
        </div>
      </Field>
      <Field label="Player involved" hint="(optional — name or ID)">
        <Input value={target} maxLength={100} onChange={(e) => setTarget(e.target.value)} placeholder="e.g. 42 or John Doe" />
      </Field>
      <Field label="What happened?">
        <Textarea value={desc} maxLength={state.maxDesc} onChange={(e) => setDesc(e.target.value)} className="min-h-[150px]"
          placeholder="Be specific: what, where, when. Include IDs if you can." />
        <div className="mt-1 text-right text-2xs tabular-nums text-fg-faint">{desc.length} / {state.maxDesc}</div>
      </Field>
      <div className="flex items-center gap-3">
        <Button variant="primary" onClick={submit} disabled={busy}><Send />Submit report</Button>
        <span className="text-2xs text-fg-faint">Up to {state.maxOpen || 1} open report{(state.maxOpen || 1) === 1 ? '' : 's'} at a time. Abuse of the report system is punishable.</span>
      </div>
    </div>
  );
}
