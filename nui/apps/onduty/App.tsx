import { useEffect, useRef, useState } from 'react';
import { Shield, Users, Clock, LogOut, Check, X, Circle, Plus, Trash2, Save, LoaderCircle } from 'lucide-react';
import {
  AppHeader, Tabs, Panel, Button, Badge, StatusIndicator, Input, Field,
  EmptyState, KeybindHint, fetchNui, useNuiEvent, useEscape, isBrowser, mockMessage,
} from '@flrp/components';
import type { DutyState, DeptAvail, UnitsState } from './types';

const dur = (s: number) => {
  s = Math.max(0, Math.floor(s));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  return (h ? `${h}h ` : '') + `${m}m ` + `${sec < 10 ? '0' : ''}${sec}s`;
};
const req = <T,>(action: string, payload: Record<string, unknown> = {}, mock?: T) =>
  fetchNui<T>('req', { action, payload }, mock);

export function App() {
  const [open, setOpen] = useState(false);
  const [view, setView] = useState<'duty' | 'units' | 'config'>('duty');
  const [state, setState] = useState<DutyState | null>(null);
  const [units, setUnits] = useState<UnitsState | null>(null);
  const [sel, setSel] = useState<string | null>(null);
  const [rank, setRank] = useState<string | null>(null);
  const [sub, setSub] = useState<string | null>(null);
  const [callsign, setCallsign] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [, force] = useState(0);
  const tick = useRef<number>();

  const close = () => { setOpen(false); fetchNui('close'); };
  useEscape(close, open);

  useNuiEvent<{ state: DutyState; view?: string }>('open', (d) => {
    setState(d.state); setOpen(true); setSel(null); setErr(null); setUnits(null);
    setView(d.view === 'units' ? 'units' : d.view === 'config' ? 'config' : 'duty');
    if (d.view === 'units') loadUnits();
  });
  useNuiEvent<{ state: DutyState }>('state', (d) => setState(d.state));
  useNuiEvent('close', () => setOpen(false));

  const loadUnits = () => req<UnitsState>('units').then((r) => setUnits(r));

  // live elapsed timers while open
  useEffect(() => {
    if (!open) return;
    tick.current = window.setInterval(() => force((n) => n + 1), 1000);
    return () => clearInterval(tick.current);
  }, [open]);
  useEffect(() => {
    if (open && view === 'units') { loadUnits(); const id = setInterval(loadUnits, 5000); return () => clearInterval(id); }
  }, [open, view]);

  // dev harness
  useEffect(() => { if (isBrowser()) mockMessage('open', { state: MOCK }); }, []);

  if (!open || !state) return null;
  const selDept = state.available.find((d) => d.id === sel) || null;

  const confirm = async () => {
    if (busy || !selDept) return;
    setBusy(true);
    const r = await req<DutyState>('goOn', {
      entity: selDept.id, rank: rank || selDept.ranks[0]?.id,
      subdivision: sub || selDept.subdivisions?.[0]?.id, callsign,
    });
    setBusy(false);
    if (!r.ok) return setErr((r as any).error || 'Failed.');
    setErr(null); setSel(null); setCallsign(''); setState(r);
  };
  const goOff = async () => {
    if (busy) return; setBusy(true);
    const r = await req<DutyState>('goOff'); setBusy(false);
    if (r.ok) setState(r);
  };
  const pick = (d: DeptAvail) => { setSel(d.id === sel ? null : d.id); setRank(d.ranks[0]?.id ?? null); setSub(d.subdivisions?.[0]?.id ?? null); setErr(null); };

  return (
    <div className="absolute inset-0 flex items-center justify-center animate-flrp-in">
      <div className={`${view === 'config' ? 'w-[720px]' : 'w-[520px]'} max-w-[95vw] overflow-hidden rounded-lg border border-border bg-bg shadow-xl shadow-black/40 animate-flrp-rise`}>
        <AppHeader title={view === 'config' ? 'Duty · Config' : 'Duty'} subtitle={state.serverName} logo={state.logo} onClose={close}
          right={view !== 'config' ? <Badge tone="neutral">{Object.values(state.counts).reduce((a, b) => a + b, 0)} on duty</Badge> : undefined} />
        {view !== 'config' && (
          <Tabs value={view} onChange={setView} className="px-4 pt-2"
            tabs={[{ id: 'duty', label: 'Duty', icon: <Shield /> }, { id: 'units', label: 'Units', icon: <Users /> }]} />
        )}

        <div className="max-h-[64vh] space-y-2.5 overflow-y-auto p-4">
          {view === 'config' ? (
            <ConfigEditor onDone={() => setView('duty')} />
          ) : view === 'duty' ? (
            <>
              {state.onDuty && (
                <Panel className="flex items-center gap-3 p-3.5">
                  <div className="min-w-0">
                    <StatusIndicator tone="success" label={`On Duty · ${state.onDuty.short}`} />
                    <div className="mt-1 text-[15px] font-bold">{state.onDuty.label}</div>
                    <div className="mt-0.5 flex items-center gap-1.5 text-xs text-fg-muted tabular-nums">
                      {state.onDuty.rankLabel}
                      {state.onDuty.subLabel && <> · <span className="font-medium text-fg">{state.onDuty.subLabel}</span></>}
                      {state.onDuty.callsign && <> · <span className="font-semibold text-fg">{state.onDuty.callsign}</span></>}
                      <span className="text-fg-faint">·</span><Clock className="size-3" />{dur(Date.now() / 1000 - state.onDuty.since)}
                    </div>
                  </div>
                  <Button variant="danger" size="md" className="ml-auto rounded-md px-4" onClick={goOff}><LogOut />Go Off Duty</Button>
                </Panel>
              )}

              <div className="px-1 pt-0.5 text-2xs font-bold uppercase tracking-wider text-fg-faint">
                {state.onDuty ? 'Switch department' : 'Departments'}
              </div>

              {state.available.length === 0 && (
                <EmptyState icon={<Shield />} title="No departments available"
                  hint="You don't hold a department role. Ask staff if that's wrong." />
              )}

              {state.available.map((d) => {
                const isOn = state.onDuty?.entity === d.id;
                return (
                <div key={d.id}>
                  <Panel className={`flex items-center gap-3 p-3.5 transition-colors ${isOn ? 'border-success/40' : sel === d.id ? 'border-primary/50 bg-panel-hover' : 'hover:bg-panel-hover'}`}>
                    <div className="min-w-0">
                      <div className="font-bold leading-tight">{d.label}</div>
                      <div className="text-2xs text-fg-muted">{d.short} · {d.ranks.map((r) => r.label).join(' / ')}</div>
                    </div>
                    <span className="ml-auto text-2xs tabular-nums text-fg-faint">{state.counts[d.id] || 0} on duty</span>
                    {isOn ? (
                      <span className="inline-flex h-9 items-center gap-1.5 rounded-md border border-success/50 bg-success/10 px-4 text-[13px] font-semibold text-success">
                        <span className="size-1.5 rounded-full bg-success" />On Duty
                      </span>
                    ) : (
                      <Button variant={sel === d.id ? 'secondary' : 'outline'} size="md" className="rounded-md px-4" onClick={() => pick(d)}>
                        {sel === d.id ? 'Selected' : 'Go On Duty'}
                      </Button>
                    )}
                  </Panel>

                  {sel === d.id && (
                    <Panel className="mt-1.5 space-y-3 border-primary/30 p-3">
                      {err && <div className="rounded-sm bg-danger/15 px-3 py-2 text-xs font-medium text-danger">{err}</div>}
                      {d.ranks.length > 1 && (
                        <Field label="Rank">
                          <div className="flex flex-wrap gap-1.5">
                            {d.ranks.map((r) => (
                              <button key={r.id} onClick={() => setRank(r.id)}
                                className={`rounded-full px-3 py-1.5 text-xs font-semibold transition-colors ${rank === r.id ? 'bg-primary/15 text-primary ring-1 ring-primary/40' : 'bg-panel-hover text-fg-muted hover:text-fg'}`}>
                                {r.label}
                              </button>
                            ))}
                          </div>
                        </Field>
                      )}
                      {d.subdivisions && d.subdivisions.length > 1 && (
                        <Field label="Subdivision">
                          <div className="flex flex-wrap gap-1.5">
                            {d.subdivisions.map((s) => (
                              <button key={s.id} onClick={() => setSub(s.id)}
                                className={`rounded-full px-3 py-1.5 text-xs font-semibold transition-colors ${sub === s.id ? 'bg-primary/15 text-primary ring-1 ring-primary/40' : 'bg-panel-hover text-fg-muted hover:text-fg'}`}>
                                {s.label}
                              </button>
                            ))}
                          </div>
                        </Field>
                      )}
                      {d.requireCallsign && (
                        <Field label="Callsign" hint="(required, e.g. 1A-12)">
                          <Input autoFocus value={callsign} maxLength={state.callsignMax}
                            onChange={(e) => setCallsign(e.target.value.toUpperCase())}
                            onKeyDown={(e) => e.key === 'Enter' && confirm()}
                            placeholder="1A-12" className="uppercase tracking-wider font-semibold" />
                        </Field>
                      )}
                      <div className="flex gap-2">
                        <Button variant="primary" onClick={confirm} disabled={busy}><Check />Confirm · {d.short}</Button>
                        <Button variant="ghost" onClick={() => setSel(null)}><X />Cancel</Button>
                      </div>
                    </Panel>
                  )}
                </div>
                );
              })}
            </>
          ) : (
            <UnitsBoard units={units} />
          )}
        </div>

        <footer className="flex items-center border-t border-border-soft bg-panel px-4 py-2.5">
          <KeybindHint keys={state.key}>Toggle</KeybindHint>
          <KeybindHint keys="Esc" className="ml-3">Close</KeybindHint>
          <span className="ml-auto text-2xs font-medium text-fg-muted">{state.serverName}</span>
        </footer>
      </div>
    </div>
  );
}

function UnitsBoard({ units }: { units: UnitsState | null }) {
  if (!units) return <EmptyState title="Loading units…" />;
  if (!units.ok) return <EmptyState icon={<Users />} title="Units unavailable" hint={units.error} />;
  return (
    <div className="space-y-2.5">
      <div className="px-1 text-xs text-fg-muted"><span className="font-bold text-fg">{units.total}</span> unit{units.total === 1 ? '' : 's'} on duty across {units.depts.length} departments</div>
      {units.depts.map((d) => (
        <Panel key={d.id} className="overflow-hidden">
          <div className="flex items-center gap-2.5 border-b border-border-soft px-3 py-2">
            <span className="font-bold">{d.short}</span>
            <span className="text-2xs text-fg-muted">{d.label}</span>
            <Badge tone={d.count ? 'primary' : 'neutral'} className="ml-auto">{d.count} on duty</Badge>
          </div>
          {d.units.length === 0 ? (
            <div className="px-3 py-2 text-xs italic text-fg-faint">No units on duty.</div>
          ) : d.units.map((u) => (
            <div key={u.src} className="grid grid-cols-[70px_1fr_auto_auto] items-center gap-2.5 border-b border-border-soft px-3 py-1.5 text-[13px] last:border-0">
              <span className={`font-bold tabular-nums tracking-wide ${u.callsign ? 'text-fg' : 'text-fg-faint font-medium'}`}>{u.callsign || '—'}</span>
              <span className="truncate">{u.name}</span>
              <span className="text-2xs text-fg-muted">{u.rank}{u.sub && <span className="text-fg-faint"> · {u.sub}</span>}</span>
              <span className="flex items-center gap-1 text-2xs text-fg-faint tabular-nums"><Circle className="size-2 fill-success text-success" />{dur(Date.now() / 1000 - u.since)}</span>
            </div>
          ))}
        </Panel>
      ))}
    </div>
  );
}

// ---- Ownership config editor ---------------------------------------------
interface EditRank { id: string; label: string; ace?: string }
interface EditSub { id: string; label: string; blip?: number; colour?: string; ace?: string }
interface EditDept {
  id: string; label: string; short: string; colour: string; blip: number;
  requireCallsign: boolean; loadout?: string; ranks: EditRank[]; subdivisions: EditSub[];
}

// A curated slice of GTA's blip-colour palette (index -> approx hex) for the picker.
const BLIP_PALETTE: { i: number; hex: string; name: string }[] = [
  { i: 0, hex: '#ffffff', name: 'White' }, { i: 40, hex: '#8a8f98', name: 'Grey' },
  { i: 1, hex: '#e03b3b', name: 'Red' }, { i: 59, hex: '#a03030', name: 'Dk Red' },
  { i: 17, hex: '#e07b2b', name: 'Orange' }, { i: 83, hex: '#b5651d', name: 'Dk Orange' },
  { i: 5, hex: '#f2d24b', name: 'Yellow' }, { i: 46, hex: '#e0b341', name: 'Gold' },
  { i: 47, hex: '#c9852b', name: 'Tan' }, { i: 60, hex: '#9c6b3b', name: 'Brown' },
  { i: 2, hex: '#4caf50', name: 'Green' }, { i: 48, hex: '#8bd450', name: 'Lt Green' },
  { i: 49, hex: '#2f7d32', name: 'Dk Green' }, { i: 50, hex: '#2bb6a8', name: 'Teal' },
  { i: 3, hex: '#3b82f6', name: 'Blue' }, { i: 38, hex: '#60a5fa', name: 'Lt Blue' },
  { i: 27, hex: '#7c5cd0', name: 'Purple' }, { i: 52, hex: '#b07cd0', name: 'Lt Purple' },
];

function BlipSwatch({ value, onChange }: { value?: number; onChange: (i: number) => void }) {
  const [open, setOpen] = useState(false);
  const cur = BLIP_PALETTE.find((b) => b.i === value);
  return (
    <div className="relative">
      <button type="button" onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-1.5 rounded-sm border border-border bg-panel px-2 py-1 text-2xs hover:bg-panel-hover">
        <span className="size-3 rounded-full border border-black/40" style={{ background: cur?.hex || '#8a8f98' }} />
        {cur ? cur.name : value != null ? `#${value}` : 'Dept default'}
      </button>
      {open && (
        <div className="absolute right-0 z-20 mt-1 grid w-[180px] grid-cols-6 gap-1.5 rounded-md border border-border bg-elevated p-2 shadow-xl shadow-black/50">
          {BLIP_PALETTE.map((b) => (
            <button key={b.i} type="button" title={`${b.name} (${b.i})`} onClick={() => { onChange(b.i); setOpen(false); }}
              className={`size-6 rounded-full border ${value === b.i ? 'ring-2 ring-primary ring-offset-1 ring-offset-elevated' : 'border-black/40'}`}
              style={{ background: b.hex }} />
          ))}
        </div>
      )}
    </div>
  );
}

const emptyDept = (): EditDept => ({ id: '', label: 'New Department', short: 'NEW', colour: '#8a8f98', blip: 0,
  requireCallsign: true, loadout: 'police', ranks: [{ id: 'patrol', label: 'Patrol', ace: '' }], subdivisions: [] });

// Dev-only preview data (browser fetchNui returns this; in-game the server responds).
const MOCK_CFG = { ok: true, departments: [
  { id: 'bso', label: "Broward Sheriff's Office", short: 'BSO', colour: '#e0b341', blip: 46, requireCallsign: true, loadout: 'police',
    ranks: [{ id: 'patrol', label: 'Patrol', ace: 'flrp.dept.bso' }, { id: 'supervisor', label: 'Supervisor', ace: 'flrp.rank.bso.supervisor' }],
    subdivisions: [{ id: 'patrol', label: 'Patrol' }, { id: 'k9', label: 'K-9 Unit', blip: 5, colour: '#f2d24b', ace: 'flrp.sub.bso.k9' }, { id: 'swat', label: 'SWAT', blip: 1, colour: '#d0453b', ace: 'flrp.sub.bso.swat' }] },
  { id: 'mpd', label: 'Miami Police Department', short: 'MPD', colour: '#3b82f6', blip: 3, requireCallsign: true, loadout: 'police',
    ranks: [{ id: 'patrol', label: 'Patrol', ace: 'flrp.dept.mpd' }],
    subdivisions: [{ id: 'patrol', label: 'Patrol' }, { id: 'k9', label: 'K-9 Unit', blip: 38, colour: '#60a5fa', ace: 'flrp.sub.mpd.k9' }] },
] as EditDept[] };

function ConfigEditor({ onDone }: { onDone: () => void }) {
  const [depts, setDepts] = useState<EditDept[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    req<{ ok: boolean; departments?: EditDept[]; error?: string }>('configGet', {}, MOCK_CFG).then((r) => {
      if (!r.ok) setErr(r.error || 'No access.');
      else setDepts(JSON.parse(JSON.stringify(r.departments || [])));
    });
  }, []);

  if (err && !depts) return <EmptyState icon={<Shield />} title="Config unavailable" hint={err} />;
  if (!depts) return <EmptyState title="Loading config…" />;

  const setDept = (i: number, patch: Partial<EditDept>) => setDepts((ds) => ds!.map((d, x) => (x === i ? { ...d, ...patch } : d)));
  const del = (i: number) => setDepts((ds) => ds!.filter((_, x) => x !== i));
  const add = () => setDepts((ds) => [...ds!, emptyDept()]);
  const save = async () => {
    setBusy(true); setErr(null);
    const r = await req<{ ok: boolean; error?: string }>('configSave', { departments: depts });
    setBusy(false);
    if (!r.ok) return setErr(r.error || 'Save failed.');
    onDone();
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2 rounded-sm bg-info/10 px-3 py-2 text-2xs text-info">
        Ownership only. Changes save to the database and apply live. Blip colours are GTA palette indices; ace fields must match a real permission (grant it in permissions.cfg).
      </div>
      {err && <div className="rounded-sm bg-danger/15 px-3 py-2 text-xs font-medium text-danger">{err}</div>}

      {depts.map((d, i) => (
        <Panel key={i} className="space-y-3 p-3">
          <div className="flex items-center gap-2">
            <input value={d.label} onChange={(e) => setDept(i, { label: e.target.value })}
              className="min-w-0 flex-1 bg-transparent text-sm font-bold outline-none" placeholder="Department name" />
            <Button variant="ghost" size="sm" className="text-danger" onClick={() => del(i)}><Trash2 />Remove</Button>
          </div>

          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <Field label="Short"><Input value={d.short} maxLength={8} onChange={(e) => setDept(i, { short: e.target.value.toUpperCase() })} className="uppercase" /></Field>
            <Field label="Menu colour">
              <div className="flex items-center gap-1.5">
                <input type="color" value={/^#/.test(d.colour) ? d.colour : '#8a8f98'} onChange={(e) => setDept(i, { colour: e.target.value })}
                  className="h-8 w-8 shrink-0 cursor-pointer rounded-sm border border-border bg-transparent p-0.5" />
                <Input value={d.colour} onChange={(e) => setDept(i, { colour: e.target.value })} className="font-mono" />
              </div>
            </Field>
            <Field label="Map blip"><BlipSwatch value={d.blip} onChange={(b) => setDept(i, { blip: b })} /></Field>
            <Field label="Loadout"><Input value={d.loadout || ''} onChange={(e) => setDept(i, { loadout: e.target.value })} placeholder="police" /></Field>
          </div>
          <label className="flex items-center gap-2 text-2xs text-fg-muted">
            <input type="checkbox" checked={d.requireCallsign} onChange={(e) => setDept(i, { requireCallsign: e.target.checked })} />
            Require a callsign to go on duty
          </label>

          <RankEditor ranks={d.ranks} deptId={d.id} onChange={(ranks) => setDept(i, { ranks })} />
          <SubEditor subs={d.subdivisions} deptId={d.id} onChange={(subdivisions) => setDept(i, { subdivisions })} />
        </Panel>
      ))}

      <Button variant="outline" size="md" className="w-full rounded-md" onClick={add}><Plus />Add Department</Button>

      <div className="sticky bottom-0 -mx-4 flex gap-2 border-t border-border-soft bg-bg px-4 py-3">
        <Button variant="primary" size="md" onClick={save} disabled={busy}>{busy ? <LoaderCircle className="animate-spin" /> : <Save />}Save changes</Button>
        <Button variant="ghost" size="md" onClick={onDone}>Discard</Button>
      </div>
    </div>
  );
}

function RankEditor({ ranks, deptId, onChange }: { ranks: EditRank[]; deptId: string; onChange: (r: EditRank[]) => void }) {
  const set = (i: number, patch: Partial<EditRank>) => onChange(ranks.map((r, x) => (x === i ? { ...r, ...patch } : r)));
  return (
    <div className="rounded-sm border border-border-soft p-2">
      <div className="mb-1.5 flex items-center justify-between text-2xs font-bold uppercase tracking-wider text-fg-faint">
        Ranks
        <Button variant="ghost" size="sm" onClick={() => onChange([...ranks, { id: '', label: 'Rank', ace: '' }])}><Plus />Add</Button>
      </div>
      <div className="space-y-1.5">
        {ranks.map((r, i) => (
          <div key={i} className="flex items-center gap-1.5">
            <Input value={r.label} onChange={(e) => set(i, { label: e.target.value })} placeholder="Label" className="w-32" />
            <Input value={r.ace || ''} onChange={(e) => set(i, { ace: e.target.value })} placeholder={`ace e.g. flrp.dept.${deptId || 'xxx'}`} className="flex-1 font-mono text-2xs" />
            <button type="button" className="text-fg-faint hover:text-danger" onClick={() => onChange(ranks.filter((_, x) => x !== i))} disabled={ranks.length <= 1}><X className="size-4" /></button>
          </div>
        ))}
      </div>
    </div>
  );
}

function SubEditor({ subs, deptId, onChange }: { subs: EditSub[]; deptId: string; onChange: (s: EditSub[]) => void }) {
  const set = (i: number, patch: Partial<EditSub>) => onChange(subs.map((s, x) => (x === i ? { ...s, ...patch } : s)));
  return (
    <div className="rounded-sm border border-border-soft p-2">
      <div className="mb-1.5 flex items-center justify-between text-2xs font-bold uppercase tracking-wider text-fg-faint">
        Subdivisions
        <Button variant="ghost" size="sm" onClick={() => onChange([...subs, { id: '', label: 'Unit' }])}><Plus />Add</Button>
      </div>
      {subs.length === 0 && <div className="px-1 py-1 text-2xs italic text-fg-faint">None — officers just go on as the department.</div>}
      <div className="space-y-1.5">
        {subs.map((s, i) => (
          <div key={i} className="flex items-center gap-1.5">
            <Input value={s.label} onChange={(e) => set(i, { label: e.target.value })} placeholder="Label" className="w-28" />
            <BlipSwatch value={s.blip} onChange={(b) => set(i, { blip: b })} />
            <Input value={s.ace || ''} onChange={(e) => set(i, { ace: e.target.value })} placeholder={`ace (blank = open) e.g. flrp.sub.${deptId || 'xxx'}.${s.id || 'unit'}`} className="flex-1 font-mono text-2xs" />
            <button type="button" className="text-fg-faint hover:text-danger" onClick={() => onChange(subs.filter((_, x) => x !== i))}><X className="size-4" /></button>
          </div>
        ))}
      </div>
    </div>
  );
}

const MOCK: DutyState = {
  ok: true, logo: '', serverName: 'Florida Roleplay', key: 'F6', callsignMax: 8, now: Date.now() / 1000,
  onDuty: { entity: 'bso', short: 'BSO', label: "Broward Sheriff's Office", colour: '#e0b341',
    rank: 'patrol', rankLabel: 'Patrol', subdivision: 'k9', subLabel: 'K-9 Unit', callsign: '1A-12', since: Date.now() / 1000 - 3725 },
  counts: { bso: 2, mpd: 1 },
  available: [
    { id: 'bso', label: "Broward Sheriff's Office", short: 'BSO', colour: '#e0b341', requireCallsign: true,
      ranks: [{ id: 'patrol', label: 'Patrol' }, { id: 'supervisor', label: 'Supervisor' }],
      subdivisions: [{ id: 'patrol', label: 'Patrol', colour: '#e0b341' }, { id: 'k9', label: 'K-9 Unit', colour: '#f2d24b' }, { id: 'swat', label: 'SWAT', colour: '#d0453b' }, { id: 'marine', label: 'Marine', colour: '#3b82f6' }] },
    { id: 'fhp', label: 'Florida Highway Patrol', short: 'FHP', colour: '#c9852b', requireCallsign: true,
      ranks: [{ id: 'patrol', label: 'Patrol' }],
      subdivisions: [{ id: 'patrol', label: 'Patrol', colour: '#c9852b' }, { id: 'motors', label: 'Motors', colour: '#e07b2b' }, { id: 'cve', label: 'CVE', colour: '#9c6b3b' }] },
    { id: 'mpd', label: 'Miami Police Department', short: 'MPD', colour: '#3b82f6', requireCallsign: true,
      ranks: [{ id: 'patrol', label: 'Patrol' }],
      subdivisions: [{ id: 'patrol', label: 'Patrol', colour: '#3b82f6' }, { id: 'k9', label: 'K-9 Unit', colour: '#60a5fa' }, { id: 'swat', label: 'SWAT', colour: '#7c5cd0' }] },
  ],
};
