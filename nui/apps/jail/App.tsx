import { useState, useMemo, useCallback } from 'react';
import { RefreshCw, X, Gavel, Ambulance, ShieldPlus, Search } from 'lucide-react';
import { fetchNui, useNuiEvent, useEscape } from '@flrp/components';
import type { State, JailPlayer } from './types';

export function App() {
  const [state, setState] = useState<State | null>(null);
  const [search, setSearch] = useState('');
  const [secs, setSecs] = useState<Record<number, number>>({});
  const [hosp, setHosp] = useState<Record<number, string>>({});
  const [armed, setArmed] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);

  useNuiEvent<{ state: State }>('open', (d) => { setState(d.state); setSearch(''); setArmed(null); });
  useNuiEvent('close', () => setState(null));

  const close = useCallback(() => { fetchNui('close'); setState(null); }, []);
  useEscape(close, !!state);

  const refresh = useCallback(async () => {
    const s = await fetchNui<State>('refresh', {}, state ?? undefined);
    if (s && s.ok) setState(s);
  }, [state]);

  const rows = useMemo(() => {
    if (!state) return [];
    const q = search.trim().toLowerCase();
    if (!q) return state.players;
    return state.players.filter((p) =>
      String(p.id).includes(q) || p.name.toLowerCase().includes(q) || p.discord.includes(q));
  }, [state, search]);

  if (!state) return null;
  const { perms } = state;

  const secOf = (id: number) => secs[id] ?? state.defaultSeconds;
  const hospOf = (id: number) => hosp[id] ?? state.hospitals[0]?.id;

  const doJail = async (p: JailPlayer) => {
    if (busy) return;
    if (armed !== p.id) { setArmed(p.id); setTimeout(() => setArmed((a) => (a === p.id ? null : a)), 3000); return; }
    setArmed(null); setBusy(true);
    await fetchNui('jail', { id: p.id, seconds: secOf(p.id) });
    setBusy(false); refresh();
  };
  const doHosp = async (p: JailPlayer, cb: string) => {
    if (busy) return; setBusy(true);
    await fetchNui(cb, { id: p.id, hospital: hospOf(p.id) });
    setBusy(false); refresh();
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/45 p-6 font-sans text-fg">
      <div className="flex max-h-[90vh] w-full max-w-[1000px] flex-col overflow-hidden rounded-lg border border-border bg-bg shadow-2xl animate-flrp-rise">

        {/* header */}
        <header className="flex items-center gap-3 border-b border-border-soft px-5 py-3.5">
          <img src={state.logo} alt="" className="size-9 rounded-md object-cover ring-1 ring-border" />
          <div className="text-lg font-bold">Jail Manager</div>
          <div className="ml-auto flex items-center gap-2">
            <button onClick={refresh}
              className="inline-flex items-center gap-1.5 rounded-sm bg-panel-hover px-3 py-1.5 text-[13px] font-semibold text-fg-muted hover:text-fg [&_svg]:size-4">
              <RefreshCw />Refresh
            </button>
            <button onClick={close}
              className="inline-flex items-center gap-1.5 rounded-sm bg-panel-hover px-3 py-1.5 text-[13px] font-semibold text-fg-muted hover:text-fg [&_svg]:size-4">
              <X />Close (Esc)
            </button>
          </div>
        </header>

        {/* search */}
        <div className="px-5 pt-4">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-fg-faint" />
            <input autoFocus value={search} onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by ID, name, or Discord…"
              className="w-full rounded-sm border border-border bg-panel px-3 py-2.5 pl-9 text-sm text-fg placeholder:text-fg-faint focus:border-primary focus:outline-none" />
          </div>
        </div>

        {/* table header */}
        <div className="grid grid-cols-[58px_minmax(150px,1fr)_168px_78px_78px_auto] items-center gap-3 px-5 pb-1.5 pt-4 text-2xs font-bold uppercase tracking-wider text-fg-faint">
          <div>ID</div><div>Name</div><div>Discord</div><div>Total Jails</div><div>Status</div>
          <div className="text-right">Action</div>
        </div>

        {/* rows */}
        <div className="flex-1 overflow-y-auto px-5 pb-2">
          {rows.length === 0
            ? <div className="py-10 text-center text-sm text-fg-faint">No players match your search.</div>
            : rows.map((p) => (
              <div key={p.id}
                className="grid grid-cols-[58px_minmax(150px,1fr)_168px_78px_78px_auto] items-center gap-3 border-b border-border-soft/70 py-2.5">
                <div className="text-[13px] font-bold text-fg-muted">[{p.id}]</div>
                <div className="truncate text-[13px] font-semibold" title={p.name}>{p.name}</div>
                <div className="truncate font-mono text-xs text-fg-muted" title={p.discord}>{p.discord || '—'}</div>
                <div className="text-sm font-bold tabular-nums">{p.total}</div>
                <div className={`text-[13px] font-semibold ${p.jailed ? 'text-danger' : 'text-success'}`}>
                  {p.jailed ? 'Jailed' : 'Free'}
                </div>

                {/* actions */}
                <div className="flex items-center justify-end gap-1.5">
                  {(perms.hospitalize || perms.leoHospitalize) && (
                    <select value={hospOf(p.id)} onChange={(e) => setHosp((h) => ({ ...h, [p.id]: e.target.value }))}
                      className="h-8 max-w-[130px] rounded-sm border border-border bg-panel px-1.5 text-xs text-fg focus:border-primary focus:outline-none">
                      {state.hospitals.map((h) => <option key={h.id} value={h.id}>{h.label}</option>)}
                    </select>
                  )}
                  {perms.jail && (
                    <>
                      <input type="number" min={1} max={state.maxSeconds} value={secOf(p.id)}
                        onChange={(e) => setSecs((s) => ({ ...s, [p.id]: Math.max(1, Math.min(state.maxSeconds, +e.target.value || 0)) }))}
                        className="h-8 w-14 rounded-sm border border-border bg-panel px-2 text-center text-xs tabular-nums text-fg focus:border-primary focus:outline-none" />
                      <button onClick={() => doJail(p)} disabled={busy}
                        className={`inline-flex h-8 items-center gap-1 rounded-sm px-2.5 text-xs font-bold text-white disabled:opacity-50 ${armed === p.id ? 'bg-warning text-black' : 'bg-danger hover:brightness-110'} [&_svg]:size-3.5`}>
                        <Gavel />{armed === p.id ? 'Confirm' : 'Jail'}
                      </button>
                    </>
                  )}
                  {perms.hospitalize && (
                    <button onClick={() => doHosp(p, 'hospitalize')} disabled={busy}
                      className="inline-flex h-8 items-center gap-1 rounded-sm bg-success px-2.5 text-xs font-bold text-white hover:brightness-110 disabled:opacity-50 [&_svg]:size-3.5">
                      <Ambulance />Hosp
                    </button>
                  )}
                  {perms.leoHospitalize && (
                    <button onClick={() => doHosp(p, 'leoHospitalize')} disabled={busy} title="LEO Hospitalize (2m)"
                      className="inline-flex h-8 items-center gap-1 rounded-sm bg-info px-2.5 text-xs font-bold text-white hover:brightness-110 disabled:opacity-50 [&_svg]:size-3.5">
                      <ShieldPlus />LEO
                    </button>
                  )}
                </div>
              </div>
            ))}
        </div>

        {/* footer */}
        <div className="border-t border-border-soft px-5 py-2.5 text-2xs text-fg-faint">
          Tip: Type <b className="text-fg-muted">/jail</b> to open this menu. Use seconds up to {state.maxSeconds}. Click <b className="text-fg-muted">Jail</b> twice to confirm.
        </div>
      </div>
    </div>
  );
}
