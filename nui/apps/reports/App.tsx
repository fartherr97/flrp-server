import { useEffect, useMemo, useState } from 'react';
import { BarChart3, CheckCircle2, FileText, Inbox, PencilLine, Plus, Search, ShieldCheck, X } from 'lucide-react';
import { cn, fetchNui, useNuiEvent, isBrowser, mockMessage } from '@flrp/components';
import { req } from './lib';
import type { State, Report } from './types';
import { Toasts } from './components/Toasts';
import { NewReport } from './components/NewReport';
import { ReportDetail } from './components/ReportDetail';
import { ReportCard } from './components/ReportCard';
import { Analytics } from './components/Analytics';
import { SettingsMenu } from './components/Settings';

const VERSION = 'v2.0';
type View = 'queue' | 'mine' | 'resolved' | 'analytics' | 'myreports';
type OpenView = View | 'new';
const rank = (s: string) => (s === 'open' ? 0 : s === 'claimed' ? 1 : 2);

export function App() {
  const [open, setOpen] = useState(false);
  const [state, setState] = useState<State | null>(null);
  const [view, setView] = useState<View>('queue');
  const [sel, setSel] = useState<number | null>(null);
  const [composing, setComposing] = useState(false);
  const [query, setQuery] = useState('');
  const [flash, setFlash] = useState<string | null>(null);

  const close = () => { setOpen(false); setComposing(false); setSel(null); fetchNui('close'); };
  const refresh = () => req<State>('state').then((s) => s.ok && setState(s));

  useNuiEvent<{ state: State; view?: OpenView; reportId?: number }>('open', (d) => {
    setState(d.state); setOpen(true); setQuery('');
    const v: OpenView = d.view || (d.state.isStaff ? 'queue' : 'myreports');
    if (d.reportId != null) { setSel(d.reportId); setView(d.state.isStaff ? 'queue' : 'myreports'); setComposing(false); return; }
    if (v === 'new') { setView('myreports'); setComposing(true); return; }
    setView(v); setComposing(false);
  });
  useNuiEvent<{ state: State }>('state', (d) => setState(d.state));
  useNuiEvent('close', () => setOpen(false));
  useEffect(() => { if (isBrowser()) mockMessage('open', { state: MOCK }); }, []);

  // ESC closes the innermost layer first: detail modal → submit dialog → menu.
  useEffect(() => {
    if (!open) return;
    const h = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      if (sel != null) return setSel(null);
      if (composing) return setComposing(false);
      close();
    };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [open, sel, composing]);

  const list = useMemo<Report[]>(() => {
    if (!state) return [];
    const all = state.reports;
    const sort = (a: Report[]) => [...a].sort((x, y) => rank(x.status) - rank(y.status) || y.createdAt - x.createdAt);
    let out: Report[] = [];
    if (view === 'queue') out = sort(all.filter((r) => r.status !== 'resolved'));
    else if (view === 'mine') out = sort(all.filter((r) => r.claimedByMe && r.status !== 'resolved'));
    else if (view === 'resolved') out = [...all.filter((r) => r.status === 'resolved')].sort((a, b) => (b.resolvedAt || 0) - (a.resolvedAt || 0));
    else if (view === 'myreports') out = sort(all);
    const q = query.trim().toLowerCase();
    if (!q) return out;
    return out.filter((r) => [String(r.id), r.reporter.name, r.target || '', r.categoryLabel, r.description, r.status, r.claimedBy || '']
      .some((v) => v.toLowerCase().includes(q)));
  }, [state, view, query]);

  if (!open || !state) return <Toasts hintKey={state?.key || 'J'} />;
  const report = sel != null ? state.reports.find((r) => r.id === sel) || null : null;
  const count = (f: (r: Report) => boolean) => state.reports.filter(f).length;
  const logo = state.logo
    ? <img src={state.logo} alt="" className="size-5 rounded-sm object-cover" />
    : <ShieldCheck className="size-[18px] text-primary" />;

  const tabs: { id: View; label: string; icon: JSX.Element; n?: number }[] = state.isStaff
    ? [{ id: 'queue', label: 'Reports', icon: <Inbox />, n: count((r) => r.status === 'open') },
       { id: 'mine', label: 'My Claims', icon: <PencilLine />, n: count((r) => r.claimedByMe && r.status !== 'resolved') },
       { id: 'resolved', label: 'Resolved', icon: <CheckCircle2 /> },
       { id: 'analytics', label: 'Analytics', icon: <BarChart3 /> }]
    : [{ id: 'myreports', label: 'My Reports', icon: <FileText />, n: count((r) => r.status !== 'resolved') }];

  const emptyText = view === 'queue' ? 'No Reports available.' : view === 'mine' ? 'You have not claimed any reports.'
    : view === 'resolved' ? 'No concluded reports yet.' : 'You have no active reports.';

  return (
    <>
      <Toasts hintKey={state.key} />
      <div className="absolute inset-0 flex items-center justify-center animate-flrp-in">
        <div className="flex w-[62dvw] min-w-[900px] max-w-[1180px] flex-col rounded-[2px] bg-bg v-shadow animate-flrp-rise">
          {/* header */}
          <div className="flex items-center gap-2 m-2">
            <h1 className="v-chip px-4 text-base">{logo}Report Menu</h1>
            <span className="v-chip ml-auto text-xs font-medium text-fg-muted"><span className="size-1.5 rounded-full bg-success" />{state.staffOnline} staff online</span>
            {!state.isStaff && <button className="v-btn v-btn-panel h-9 rounded" onClick={() => setComposing(true)}><Plus />New Report</button>}
            <SettingsMenu />
            <button className="v-btn v-btn-panel h-9 w-9 rounded px-0" onClick={close} aria-label="Close"><X className="size-4" /></button>
          </div>
          <div className="h-px bg-border" />

          {/* segmented control + search */}
          <div className="relative m-5 flex items-center justify-center">
            <div className="v-seg">
              {tabs.map((t) => (
                <button key={t.id} className="v-seg-item" data-active={view === t.id} onClick={() => { setView(t.id); setQuery(''); }}>
                  {t.icon}{t.label}
                  {t.n != null && t.n > 0 && <span className={cn('ml-0.5 min-w-[18px] rounded-[2px] px-1 text-center text-xs font-bold tabular-nums', t.id === 'queue' ? 'bg-primary text-primary-fg' : 'bg-bg text-fg-muted')}>{t.n}</span>}
                </button>
              ))}
            </div>
            {view !== 'analytics' && (
              <div className="absolute right-0 top-0 flex h-full items-center">
                <div className="relative">
                  <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-fg-faint" />
                  <input className="v-input h-[34px] w-[220px] rounded-[8px] border bg-panel text-sm" style={{ paddingLeft: 32 }} placeholder="Search..." value={query} onChange={(e) => setQuery(e.target.value)} />
                </div>
              </div>
            )}
          </div>

          {/* content box */}
          <div className="mx-5 mb-2 h-[55dvh] overflow-y-auto rounded-[8px] border border-border">
            {view === 'analytics'
              ? <div className="p-5"><Analytics /></div>
              : list.length === 0
                ? <div className="flex h-full items-center justify-center text-sm text-fg-muted">{query ? 'Nothing matches your search.' : emptyText}</div>
                : <div className="grid grid-cols-2 gap-4 p-5 md:grid-cols-3 lg:grid-cols-4">
                    {list.map((r) => <ReportCard key={r.id} r={r} staff={state.isStaff} onClick={() => setSel(r.id)} />)}
                  </div>}
          </div>

          <div className="m-2 flex items-center px-1 text-xs text-fg-muted">
            {flash && <span className="font-medium text-success">{flash}</span>}
            <span className="ml-auto flex items-center gap-2">
              <span className="text-fg-faint">Press <kbd className="rounded-[2px] border border-border bg-panel px-1 font-bold text-fg-muted">{state.key}</kbd> to toggle</span>
              <span>{state.serverName} · {VERSION}</span>
            </span>
          </div>
        </div>
      </div>

      <ReportDetail state={state} report={report} onClose={() => setSel(null)} onChange={refresh} />
      <NewReport state={state} open={composing} logo={logo} onClose={() => setComposing(false)}
        onDone={(s, id) => { setState(s); setComposing(false); setView('myreports'); setFlash(`Report #${id} submitted — staff have been notified.`); setTimeout(() => setFlash(null), 8000); }} />
    </>
  );
}

const MOCK: State = {
  ok: true, isStaff: true, canSelfClaim: false, me: { src: 1, name: 'Owner | Mike' }, staffOnline: 2,
  logo: '', serverName: 'Florida Roleplay', key: 'J', toastSeconds: 12, maxDesc: 600, maxMsg: 400, maxOpen: 3, now: Date.now() / 1000, nearbyDistance: 20,
  categories: [{ id: 'player', label: 'Player Report', colour: '#ff6b6b' }, { id: 'bug', label: 'Bug', colour: '#f5b342' }, { id: 'question', label: 'Question', colour: '#00bfc4' }],
  reports: [
    { id: 12, category: 'player', categoryLabel: 'Player Report', categoryColour: '#ff6b6b', description: 'RDM at Legion Square, id 42 shot me on sight while I was in a traffic stop.', target: '42', status: 'open',
      reporter: { name: '770 | Officer | N. Ducky', src: 7, online: true }, claimedByMe: false, own: false, createdAt: Date.now() / 1000 - 320, messages: [],
      nearby: [{ id: 42, name: 'John Doe', distance: 4.2 }, { id: 9, name: 'Trooper Smith', distance: 12.8 }] },
    { id: 11, category: 'bug', categoryLabel: 'Bug', categoryColour: '#f5b342', description: 'Fell through the map near Sandy Shores gas station.', status: 'claimed',
      reporter: { name: 'Civ | Jane', src: 3, online: false }, claimedBy: 'Owner | Mike', claimedByMe: true, own: false, createdAt: Date.now() / 1000 - 1900, claimedAt: Date.now() / 1000 - 1700,
      messages: [{ name: 'Owner | Mike', staff: true, body: 'Looking into it now.', at: Date.now() / 1000 - 1600 }] },
  ],
};
