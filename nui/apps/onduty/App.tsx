import { useEffect, useRef, useState } from 'react';
import { Shield, Users, Clock, LogOut, Check, X, Circle } from 'lucide-react';
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
  const [view, setView] = useState<'duty' | 'units'>('duty');
  const [state, setState] = useState<DutyState | null>(null);
  const [units, setUnits] = useState<UnitsState | null>(null);
  const [sel, setSel] = useState<string | null>(null);
  const [rank, setRank] = useState<string | null>(null);
  const [callsign, setCallsign] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [, force] = useState(0);
  const tick = useRef<number>();

  const close = () => { setOpen(false); fetchNui('close'); };
  useEscape(close, open);

  useNuiEvent<{ state: DutyState; view?: string }>('open', (d) => {
    setState(d.state); setOpen(true); setSel(null); setErr(null); setUnits(null);
    setView(d.view === 'units' ? 'units' : 'duty');
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
    const r = await req<DutyState>('goOn', { entity: selDept.id, rank: rank || selDept.ranks[0]?.id, callsign });
    setBusy(false);
    if (!r.ok) return setErr((r as any).error || 'Failed.');
    setErr(null); setSel(null); setCallsign(''); setState(r);
  };
  const goOff = async () => {
    if (busy) return; setBusy(true);
    const r = await req<DutyState>('goOff'); setBusy(false);
    if (r.ok) setState(r);
  };
  const pick = (d: DeptAvail) => { setSel(d.id === sel ? null : d.id); setRank(d.ranks[0]?.id ?? null); setErr(null); };

  return (
    <div className="absolute inset-0 flex items-center justify-center animate-flrp-in">
      <div className="w-[520px] max-w-[92vw] overflow-hidden rounded-lg border border-border bg-bg shadow-xl shadow-black/40 animate-flrp-rise">
        <AppHeader title="Duty" subtitle={state.serverName} logo={state.logo} onClose={close}
          right={<Badge tone="neutral">{Object.values(state.counts).reduce((a, b) => a + b, 0)} on duty</Badge>} />
        <Tabs value={view} onChange={setView} className="px-4 pt-2"
          tabs={[{ id: 'duty', label: 'Duty', icon: <Shield /> }, { id: 'units', label: 'Units', icon: <Users /> }]} />

        <div className="max-h-[62vh] space-y-2.5 overflow-y-auto p-4">
          {view === 'duty' ? (
            <>
              {state.onDuty && (
                <Panel className="flex items-center gap-3 p-3.5">
                  <span className="h-11 w-1.5 shrink-0 rounded" style={{ background: state.onDuty.colour }} />
                  <div className="min-w-0">
                    <StatusIndicator tone="success" label={`On Duty · ${state.onDuty.short}`} />
                    <div className="mt-1 text-[15px] font-bold">{state.onDuty.label}</div>
                    <div className="mt-0.5 flex items-center gap-1.5 text-xs text-fg-muted tabular-nums">
                      {state.onDuty.rankLabel}{state.onDuty.callsign && <> · <span className="font-semibold text-fg">{state.onDuty.callsign}</span></>}
                      <span className="text-fg-faint">·</span><Clock className="size-3" />{dur(Date.now() / 1000 - state.onDuty.since)}
                    </div>
                  </div>
                  <Button variant="danger" className="ml-auto" onClick={goOff}><LogOut />Go Off Duty</Button>
                </Panel>
              )}

              <div className="px-1 pt-0.5 text-2xs font-bold uppercase tracking-wider text-fg-faint">
                {state.onDuty ? 'Switch department' : 'Departments'}
              </div>

              {state.available.length === 0 && (
                <EmptyState icon={<Shield />} title="No departments available"
                  hint="You don't hold a department role. Ask staff if that's wrong." />
              )}

              {state.available.map((d) => (
                <div key={d.id}>
                  <Panel className={`flex items-center gap-3 p-3 transition-colors ${sel === d.id ? 'border-primary/50 bg-panel-hover' : 'hover:bg-panel-hover'}`}>
                    <span className="h-6 w-1 shrink-0 rounded" style={{ background: d.colour }} />
                    <div className="min-w-0">
                      <div className="font-bold leading-tight">{d.label}</div>
                      <div className="text-2xs text-fg-muted">{d.short} · {d.ranks.map((r) => r.label).join(' / ')}</div>
                    </div>
                    <span className="ml-auto text-2xs tabular-nums text-fg-faint">{state.counts[d.id] || 0} on duty</span>
                    <Button variant={sel === d.id ? 'secondary' : 'primary'} size="sm" onClick={() => pick(d)}>
                      {sel === d.id ? 'Selected' : 'Go On Duty'}
                    </Button>
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
              ))}
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
            <span className="h-4 w-1 rounded" style={{ background: d.colour }} />
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
              <span className="text-2xs text-fg-muted">{u.rank}</span>
              <span className="flex items-center gap-1 text-2xs text-fg-faint tabular-nums"><Circle className="size-2 fill-success text-success" />{dur(Date.now() / 1000 - u.since)}</span>
            </div>
          ))}
        </Panel>
      ))}
    </div>
  );
}

const MOCK: DutyState = {
  ok: true, onDuty: null, logo: '', serverName: 'Florida Roleplay', key: 'F6', callsignMax: 8, now: Date.now() / 1000,
  counts: { bso: 2, mpd: 1 },
  available: [
    { id: 'bso', label: "Broward Sheriff's Office", short: 'BSO', colour: '#e0b341', requireCallsign: true, ranks: [{ id: 'patrol', label: 'Patrol' }, { id: 'supervisor', label: 'Supervisor' }] },
    { id: 'fhp', label: 'Florida Highway Patrol', short: 'FHP', colour: '#c9852b', requireCallsign: true, ranks: [{ id: 'patrol', label: 'Patrol' }] },
    { id: 'mpd', label: 'Miami Police Department', short: 'MPD', colour: '#3b82f6', requireCallsign: true, ranks: [{ id: 'patrol', label: 'Patrol' }] },
  ],
};
