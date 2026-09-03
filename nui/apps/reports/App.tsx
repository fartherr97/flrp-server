import { useEffect, useMemo, useState } from 'react';
import { Inbox, PencilLine, CheckCircle2, BarChart3, Plus, FileText, ListChecks } from 'lucide-react';
import { AppHeader, Badge, StatusIndicator, EmptyState, KeybindHint, cn, fetchNui, useNuiEvent, useEscape, isBrowser, mockMessage } from '@flrp/components';
import { req, ago, statusTone } from './lib';
import type { State, Report } from './types';
import { Toasts } from './components/Toasts';
import { NewReport } from './components/NewReport';
import { ReportDetail } from './components/ReportDetail';
import { Analytics } from './components/Analytics';

type View = 'queue' | 'mine' | 'resolved' | 'analytics' | 'new' | 'myreports';
const rank = (s: string) => (s === 'open' ? 0 : s === 'claimed' ? 1 : 2);

export function App() {
  const [open, setOpen] = useState(false);
  const [state, setState] = useState<State | null>(null);
  const [view, setView] = useState<View>('queue');
  const [sel, setSel] = useState<number | null>(null);

  const close = () => { setOpen(false); fetchNui('close'); };
  useEscape(close, open);
  const refresh = () => req<State>('state').then((s) => s.ok && setState(s));

  useNuiEvent<{ state: State; view?: View; reportId?: number }>('open', (d) => {
    setState(d.state); setOpen(true);
    let v: View = d.view || (d.state.isStaff ? 'queue' : 'new');
    if (d.reportId != null) { setSel(d.reportId); v = d.state.isStaff ? 'queue' : 'myreports'; }
    setView(v);
  });
  useNuiEvent<{ state: State }>('state', (d) => setState(d.state));
  useNuiEvent('close', () => setOpen(false));
  useEffect(() => { if (isBrowser()) mockMessage('open', { state: MOCK }); }, []);

  const list = useMemo<Report[]>(() => {
    if (!state) return [];
    const all = state.reports;
    const sort = (a: Report[]) => [...a].sort((x, y) => rank(x.status) - rank(y.status) || y.createdAt - x.createdAt);
    if (view === 'queue') return sort(all.filter((r) => r.status !== 'resolved'));
    if (view === 'mine') return sort(all.filter((r) => r.claimedByMe && r.status !== 'resolved'));
    if (view === 'resolved') return [...all.filter((r) => r.status === 'resolved')].sort((a, b) => (b.resolvedAt || 0) - (a.resolvedAt || 0));
    if (view === 'myreports') return sort(all);
    return [];
  }, [state, view]);

  if (!open || !state) return <Toasts hintKey={state?.key || 'J'} />;
  const report = sel != null ? state.reports.find((r) => r.id === sel) || null : null;
  const count = (f: (r: Report) => boolean) => state.reports.filter(f).length;

  const nav: { id: View; label: string; icon: JSX.Element; n?: number; hot?: boolean }[] = state.isStaff
    ? [{ id: 'queue', label: 'Queue', icon: <Inbox />, n: count((r) => r.status === 'open'), hot: true },
       { id: 'mine', label: 'My Claims', icon: <PencilLine />, n: count((r) => r.claimedByMe && r.status !== 'resolved') },
       { id: 'resolved', label: 'Resolved', icon: <CheckCircle2 />, n: count((r) => r.status === 'resolved') },
       { id: 'analytics', label: 'Analytics', icon: <BarChart3 /> }]
    : [{ id: 'new', label: 'New Report', icon: <Plus /> },
       { id: 'myreports', label: 'My Reports', icon: <FileText />, n: count((r) => r.status !== 'resolved'), hot: true }];

  const showList = view !== 'analytics' && view !== 'new';

  return (
    <>
      <Toasts hintKey={state.key} />
      <div className="absolute inset-0 flex items-center justify-center animate-flrp-in">
        <div className="flex h-[660px] max-h-[92vh] w-[1060px] max-w-[95vw] flex-col overflow-hidden rounded-lg border border-border bg-bg shadow-xl shadow-black/50 animate-flrp-rise">
          <AppHeader title="FLRP Reports" subtitle={state.isStaff ? 'Staff Console' : 'Player Support'} logo={state.logo} onClose={close}
            right={<Badge tone="neutral">{state.staffOnline} staff online</Badge>} />
          <div className="flex min-h-0 flex-1">
            <nav className="flex w-[200px] flex-col gap-1 border-r border-border-soft bg-panel p-3">
              {nav.map((it) => (
                <button key={it.id} onClick={() => { setView(it.id); setSel(view !== it.id ? null : sel); }}
                  className={cn('flex items-center gap-2.5 rounded px-3 py-2 text-left text-[13px] font-semibold transition-colors [&_svg]:size-4',
                    view === it.id ? 'bg-primary/15 text-fg shadow-[inset_2px_0_0] shadow-primary' : 'text-fg-muted hover:bg-panel-hover hover:text-fg')}>
                  {it.icon}<span>{it.label}</span>
                  {it.n != null && <span className={cn('ml-auto min-w-[22px] rounded-full px-1.5 text-center text-2xs font-bold tabular-nums',
                    it.n > 0 && it.hot ? 'bg-primary text-primary-fg' : it.n > 0 && it.id === 'queue' ? 'bg-warning text-black' : 'bg-panel-hover text-fg-muted')}>{it.n}</span>}
                </button>
              ))}
              <div className="mt-auto px-1 text-2xs leading-relaxed text-fg-faint">
                {state.isStaff ? <>New reports pop a toast — press <b>{state.key}</b> while it shows to jump to it.</> : <>Type <b>/report</b> or <b>/calladmin</b> any time.</>}
              </div>
            </nav>

            <main className="flex min-w-0 flex-1">
              {showList && (
                <section className="flex w-[380px] flex-col gap-2 overflow-y-auto border-r border-border-soft p-3">
                  <div className="px-1 pt-0.5 text-2xs font-bold uppercase tracking-wider text-fg-faint">
                    {({ queue: 'Live queue', mine: 'Claimed by you', resolved: 'Recently resolved', myreports: 'Your reports' } as any)[view]} · {list.length}
                  </div>
                  {list.length === 0
                    ? <EmptyState icon={view === 'queue' ? <CheckCircle2 /> : <ListChecks />} title={view === 'queue' ? 'Queue is clear' : view === 'mine' ? 'Nothing claimed' : view === 'resolved' ? 'No resolved reports yet' : 'You have no reports'} />
                    : list.map((r) => (
                      <button key={r.id} onClick={() => setSel(r.id)}
                        className={cn('flex flex-col gap-1.5 rounded-lg border p-3 text-left transition-colors',
                          sel === r.id ? 'border-primary/40 bg-primary/10' : 'border-transparent bg-panel hover:bg-panel-hover')}>
                        <div className="flex items-center gap-2">
                          <span className="text-2xs font-bold tabular-nums text-fg-muted">#{r.id}</span>
                          <Badge tone="neutral"><span className="size-1.5 rounded-full" style={{ background: r.categoryColour }} />{r.categoryLabel}</Badge>
                          <span className="ml-auto text-2xs tabular-nums text-fg-faint">{ago(r.createdAt)}</span>
                        </div>
                        <div className="font-semibold">{r.reporter.name}{r.target && <span className="font-medium text-fg-faint"> vs {r.target}</span>}</div>
                        <div className="line-clamp-2 text-xs leading-snug text-fg-muted">{r.description}</div>
                        <div className="flex items-center gap-2 text-2xs text-fg-faint">
                          <StatusIndicator tone={statusTone(r.status)} label={r.status} />
                          {r.claimedBy && <span>{r.claimedByMe ? 'you' : r.claimedBy}</span>}
                          {r.messages.length > 0 && <span className="ml-auto">✉ {r.messages.length}</span>}
                        </div>
                      </button>
                    ))}
                </section>
              )}
              {view === 'new' ? <div className="flex-1 overflow-y-auto p-5"><NewReport state={state} onDone={(s) => { setState(s); setView('myreports'); }} /></div>
                : view === 'analytics' ? <div className="flex-1 overflow-y-auto p-5"><Analytics /></div>
                : <ReportDetail state={state} report={report} onChange={refresh} />}
            </main>
          </div>
          <footer className="flex items-center border-t border-border-soft bg-panel px-4 py-2.5">
            <KeybindHint keys={state.key}>Toggle</KeybindHint><KeybindHint keys="Esc" className="ml-3">Close</KeybindHint>
            <span className="ml-auto text-2xs font-medium text-fg-muted">{state.serverName}</span>
          </footer>
        </div>
      </div>
    </>
  );
}

const MOCK: State = {
  ok: true, isStaff: true, canSelfClaim: false, me: { src: 1, name: 'Owner | Mike' }, staffOnline: 1,
  logo: '', serverName: 'Florida Roleplay', key: 'J', toastSeconds: 12, maxDesc: 600, maxMsg: 400, maxOpen: 3, now: Date.now() / 1000,
  categories: [{ id: 'player', label: 'Player Report', colour: '#ff6b6b' }, { id: 'bug', label: 'Bug', colour: '#f5b342' }, { id: 'question', label: 'Question', colour: '#00bfc4' }],
  reports: [{ id: 1, category: 'player', categoryLabel: 'Player Report', categoryColour: '#ff6b6b', description: 'RDM at Legion Square, id 42 shot me on sight.', target: '42', status: 'open',
    reporter: { name: '100 | Owner | Mike', src: 1, online: true }, claimedByMe: false, own: false, createdAt: Date.now() / 1000 - 320, messages: [] }],
};
