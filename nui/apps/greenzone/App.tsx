import { useState, useCallback } from 'react';
import { RefreshCw, X, MapPinPlus, MapPin, Trash2, ShieldBan, HeartPulse, CarFront, Shield } from 'lucide-react';
import { fetchNui, useNuiEvent, useEscape } from '@flrp/components';
import type { State, Zone, ZoneOption } from './types';

const OPT_ICON: Record<string, any> = { weapons: ShieldBan, damage: HeartPulse, vehicles: CarFront };

function OptToggle({ opt, on, onClick }: { opt: ZoneOption; on: boolean; onClick: () => void }) {
  const Icon = OPT_ICON[opt.key] ?? Shield;
  return (
    <button onClick={onClick} title={opt.desc}
      className={`inline-flex items-center gap-1.5 rounded-sm px-2.5 py-1.5 text-xs font-semibold [&_svg]:size-3.5 ${on ? 'bg-success/20 text-success' : 'bg-panel-hover text-fg-faint hover:text-fg-muted'}`}>
      <Icon />{opt.label}
    </button>
  );
}

export function App() {
  const [state, setState] = useState<State | null>(null);
  const [busy, setBusy] = useState(false);
  const [nName, setNName] = useState('Safe Zone');
  const [nRad, setNRad] = useState(30);
  const [nOpt, setNOpt] = useState<Record<string, boolean>>({ weapons: true, damage: true, vehicles: false });
  const [armedDel, setArmedDel] = useState<number | null>(null);

  useNuiEvent<{ state: State }>('open', (d) => { setState(d.state); setNRad(d.state.defaultRadius); });
  useNuiEvent('close', () => setState(null));

  const close = useCallback(() => { fetchNui('close'); setState(null); }, []);
  useEscape(close, !!state);

  const refresh = useCallback(async () => {
    const s = await fetchNui<State>('refresh', {}, state ?? undefined);
    if (s && s.ok) setState(s);
  }, [state]);

  if (!state) return null;

  const send = async (cb: string, data: Record<string, unknown>) => {
    if (busy) return; setBusy(true);
    const s = await fetchNui<State>(cb, data, state);
    setBusy(false);
    if (s && s.ok) setState(s);
  };

  const create = () => send('create', { name: nName.trim() || 'Safe Zone', radius: nRad, ...nOpt });
  const update = (z: Zone, patch: Partial<Zone>) => send('update', { id: z.id, ...patch });
  const del = (z: Zone) => {
    if (armedDel !== z.id) { setArmedDel(z.id); setTimeout(() => setArmedDel((a) => (a === z.id ? null : a)), 3000); return; }
    setArmedDel(null); send('delete', { id: z.id });
  };
  const tp = (z: Zone) => fetchNui('tp', { id: z.id });

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/45 p-6 font-sans text-fg">
      <div className="flex max-h-[90vh] w-full max-w-[860px] flex-col overflow-hidden rounded-lg border border-border bg-bg shadow-2xl animate-flrp-rise">

        <header className="flex items-center gap-3 border-b border-border-soft px-5 py-3.5">
          <img src={state.logo} alt="" className="size-9 rounded-md object-cover ring-1 ring-border" />
          <div><div className="text-lg font-bold leading-tight">Green Zones</div>
            <div className="text-xs text-fg-muted">Safe-zone manager</div></div>
          <div className="ml-auto flex items-center gap-2">
            <button onClick={refresh} className="inline-flex items-center gap-1.5 rounded-sm bg-panel-hover px-3 py-1.5 text-[13px] font-semibold text-fg-muted hover:text-fg [&_svg]:size-4"><RefreshCw />Refresh</button>
            <button onClick={close} className="inline-flex items-center gap-1.5 rounded-sm bg-panel-hover px-3 py-1.5 text-[13px] font-semibold text-fg-muted hover:text-fg [&_svg]:size-4"><X />Close (Esc)</button>
          </div>
        </header>

        {/* create */}
        <div className="border-b border-border-soft bg-panel/40 px-5 py-4">
          <div className="mb-2.5 text-2xs font-bold uppercase tracking-wider text-fg-faint">Create a zone at your location</div>
          <div className="flex flex-wrap items-center gap-2">
            <input value={nName} onChange={(e) => setNName(e.target.value)} maxLength={64} placeholder="Zone name"
              className="h-9 min-w-[160px] flex-1 rounded-sm border border-border bg-panel px-3 text-sm text-fg placeholder:text-fg-faint focus:border-primary focus:outline-none" />
            <label className="flex items-center gap-1.5 text-xs text-fg-muted">Radius
              <input type="number" min={state.minRadius} max={state.maxRadius} value={nRad}
                onChange={(e) => setNRad(Math.max(state.minRadius, Math.min(state.maxRadius, +e.target.value || state.minRadius)))}
                className="h-9 w-20 rounded-sm border border-border bg-panel px-2 text-center text-sm tabular-nums text-fg focus:border-primary focus:outline-none" />m
            </label>
            {state.options.map((o) => (
              <OptToggle key={o.key} opt={o} on={!!nOpt[o.key]} onClick={() => setNOpt((s) => ({ ...s, [o.key]: !s[o.key] }))} />
            ))}
            <button onClick={create} disabled={busy}
              className="ml-auto inline-flex h-9 items-center gap-1.5 rounded-sm bg-success px-3.5 text-[13px] font-bold text-white hover:brightness-110 disabled:opacity-50 [&_svg]:size-4">
              <MapPinPlus />Create Zone Here
            </button>
          </div>
        </div>

        {/* zones */}
        <div className="flex-1 overflow-y-auto p-5">
          <div className="mb-2 text-2xs font-bold uppercase tracking-wider text-fg-faint">{state.zones.length} zone{state.zones.length === 1 ? '' : 's'}</div>
          {state.zones.length === 0
            ? <div className="py-8 text-center text-sm text-fg-faint">No zones yet — create one above.</div>
            : <div className="space-y-2.5">
              {state.zones.map((z) => (
                <div key={z.id} className="rounded-md border border-border-soft bg-panel/60 p-3">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="rounded bg-panel-hover px-1.5 py-0.5 text-2xs font-bold text-fg-faint">#{z.id}</span>
                    <input defaultValue={z.name} maxLength={64} onBlur={(e) => e.target.value.trim() && e.target.value !== z.name && update(z, { name: e.target.value.trim() })}
                      className="h-8 min-w-[150px] flex-1 rounded-sm border border-transparent bg-transparent px-1.5 text-sm font-semibold text-fg hover:border-border focus:border-primary focus:bg-panel focus:outline-none" />
                    <label className="flex items-center gap-1.5 text-xs text-fg-muted">Radius
                      <input type="number" min={state.minRadius} max={state.maxRadius} defaultValue={Math.round(z.radius)}
                        onBlur={(e) => { const v = Math.max(state.minRadius, Math.min(state.maxRadius, +e.target.value || z.radius)); if (v !== z.radius) update(z, { radius: v }); }}
                        className="h-8 w-16 rounded-sm border border-border bg-panel px-2 text-center text-xs tabular-nums text-fg focus:border-primary focus:outline-none" />m
                    </label>
                    <button onClick={() => tp(z)} title="Teleport to zone"
                      className="inline-flex h-8 items-center gap-1 rounded-sm bg-panel-hover px-2.5 text-xs font-semibold text-fg-muted hover:text-fg [&_svg]:size-3.5"><MapPin />TP</button>
                    <button onClick={() => del(z)} disabled={busy} title="Delete zone"
                      className={`inline-flex h-8 items-center gap-1 rounded-sm px-2.5 text-xs font-bold disabled:opacity-50 [&_svg]:size-3.5 ${armedDel === z.id ? 'bg-danger text-white' : 'bg-danger/15 text-danger hover:bg-danger/25'}`}>
                      <Trash2 />{armedDel === z.id ? 'Confirm' : 'Delete'}</button>
                  </div>
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    {state.options.map((o) => (
                      <OptToggle key={o.key} opt={o} on={!!z[o.key]} onClick={() => update(z, { [o.key]: !z[o.key] } as Partial<Zone>)} />
                    ))}
                  </div>
                </div>
              ))}
            </div>}
        </div>

        <div className="border-t border-border-soft px-5 py-2.5 text-2xs text-fg-faint">
          Type <b className="text-fg-muted">/greenzones</b> (or <b className="text-fg-muted">/gz</b>) to open. Zones sync live and show a green blip on the map. Delete needs two clicks.
        </div>
      </div>
    </div>
  );
}
