import { useEffect, useMemo, useRef, useState } from 'react';
import { Vote, Plus, Trash2, Play, X, Timer, Check, Trophy } from 'lucide-react';
import { AppHeader, Button, Input, fetchNui, useNuiEvent, isBrowser, mockMessage } from '@flrp/components';

type Limits = { maxOptions?: number; minSeconds?: number; maxSeconds?: number; defaultSeconds?: number };
type Ballot = { title: string; options: string[]; seconds: number };
type Results = { title: string; options: string[]; counts: number[]; total: number; winner: number; seconds: number };
type View = 'config' | 'ballot' | 'results' | null;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

export function App() {
  const [view, setView] = useState<View>(null);

  useNuiEvent<{ limits: Limits }>('config', (d) => { setLimits(d.limits || {}); setView('config'); });
  useNuiEvent<{ ballot: Ballot }>('ballot', (d) => { setBallot(d.ballot); setView('ballot'); });
  useNuiEvent<{ results: Results }>('results', (d) => { setResults(d.results); setView('results'); });
  useNuiEvent('close', () => setView(null));

  // ---- builder state ----
  const [limits, setLimits] = useState<Limits>({});
  const [title, setTitle] = useState('');
  const [options, setOptions] = useState<string[]>(['', '']);
  const [seconds, setSeconds] = useState(60);
  const maxOptions = limits.maxOptions ?? 8;

  useEffect(() => {
    if (view === 'config') { setTitle(''); setOptions(['', '']); setSeconds(limits.defaultSeconds ?? 60); }
  }, [view]);

  const [ballot, setBallot] = useState<Ballot | null>(null);
  const [results, setResults] = useState<Results | null>(null);

  // dev harness
  useEffect(() => {
    if (!isBrowser()) return;
    mockMessage('ballot', { ballot: { title: 'Where should the AOP be?', options: ['Sandy Shores', 'Paleto Bay', 'Vinewood', 'Legion Square'], seconds: 45 } });
  }, []);

  if (view === 'config') {
    const opts = options;
    const valid = title.trim().length > 0 && opts.filter((o) => o.trim()).length >= 2;
    const setOpt = (i: number, v: string) => setOptions((a) => a.map((o, j) => (j === i ? v : o)));
    const start = () => {
      if (!valid) return;
      fetchNui('start', { title: title.trim(), options: opts.map((o) => o.trim()).filter(Boolean), seconds });
    };
    return (
      <div className="absolute inset-0 flex items-center justify-center bg-black/55 animate-flrp-in">
        <div className="w-[480px] max-w-[95vw] overflow-hidden rounded-lg border border-border bg-bg shadow-xl shadow-black/40 animate-flrp-rise">
          <AppHeader title="Start a vote" subtitle="Everyone gets a ballot they must answer" onClose={() => fetchNui('dismiss')} />
          <div className="space-y-3 p-4">
            <label className="block">
              <span className="mb-1 block text-2xs font-bold uppercase tracking-wider text-fg-faint">Question</span>
              <Input value={title} maxLength={120} placeholder="e.g. Where should the AOP be?" onChange={(e) => setTitle(e.target.value)} />
            </label>
            <div>
              <span className="mb-1 block text-2xs font-bold uppercase tracking-wider text-fg-faint">Options</span>
              <div className="space-y-1.5">
                {opts.map((o, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <Input value={o} maxLength={80} placeholder={`Option ${i + 1}`} onChange={(e) => setOpt(i, e.target.value)} />
                    {opts.length > 2 && (
                      <Button size="sm" variant="ghost" onClick={() => setOptions((a) => a.filter((_, j) => j !== i))}><Trash2 /></Button>
                    )}
                  </div>
                ))}
              </div>
              {opts.length < maxOptions && (
                <Button size="sm" variant="outline" className="mt-2" onClick={() => setOptions((a) => [...a, ''])}><Plus /> Add option</Button>
              )}
            </div>
            <label className="flex items-center gap-2">
              <span className="text-2xs font-bold uppercase tracking-wider text-fg-faint">Timer</span>
              <Input type="number" className="w-24" value={seconds}
                onChange={(e) => setSeconds(clamp(parseInt(e.target.value, 10) || 0, limits.minSeconds ?? 10, limits.maxSeconds ?? 600))} />
              <span className="text-xs text-fg-muted">seconds</span>
            </label>
          </div>
          <footer className="flex justify-end gap-2 border-t border-border-soft bg-panel px-4 py-3">
            <Button variant="ghost" onClick={() => fetchNui('dismiss')}>Cancel</Button>
            <Button variant="primary" disabled={!valid} onClick={start}><Play /> Start vote</Button>
          </footer>
        </div>
      </div>
    );
  }

  if (view === 'ballot' && ballot) return <BallotView ballot={ballot} />;
  if (view === 'results' && results) return <ResultsView results={results} onDone={() => fetchNui('dismiss')} />;
  return null;
}

function BallotView({ ballot }: { ballot: Ballot }) {
  const endsAt = useRef(Date.now() + ballot.seconds * 1000);
  const [left, setLeft] = useState(ballot.seconds);
  const [cast, setCast] = useState<number | null>(null);
  useEffect(() => {
    const id = setInterval(() => setLeft(Math.max(0, Math.ceil((endsAt.current - Date.now()) / 1000))), 250);
    return () => clearInterval(id);
  }, []);
  const pct = clamp((left / ballot.seconds) * 100, 0, 100);
  const vote = (i: number) => { if (cast !== null) return; setCast(i); fetchNui('cast', { index: i + 1 }); };

  return (
    <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/80 backdrop-blur-sm animate-flrp-in">
      <div className="mb-1 flex items-center gap-2 text-2xs font-bold uppercase tracking-[0.2em] text-primary">
        <Vote className="size-4" /> Server Vote
      </div>
      <h1 className="max-w-[820px] px-6 text-center text-3xl font-extrabold tracking-tight text-white [text-wrap:balance]">{ballot.title}</h1>
      <div className="mt-1.5 flex items-center gap-1.5 text-sm font-bold tabular-nums text-fg-muted">
        <Timer className="size-4 text-primary" /> {left}s
      </div>
      <div className="mt-5 grid w-[min(760px,92vw)] grid-cols-2 gap-3">
        {ballot.options.map((o, i) => (
          <button key={i} onClick={() => vote(i)} disabled={cast !== null}
            className={`flex min-h-[64px] items-center justify-center rounded-lg border-2 px-5 text-center text-lg font-bold transition-all ${
              cast === i ? 'border-success bg-success/20 text-success'
              : cast !== null ? 'border-border/50 bg-panel/40 text-fg-faint'
              : 'border-border bg-panel/70 text-white hover:border-primary hover:bg-primary/15'}`}>
            {cast === i && <Check className="mr-2 size-5" />}{o}
          </button>
        ))}
      </div>
      <p className="mt-4 text-xs font-medium text-white/60">
        {cast !== null ? 'Vote cast — waiting for results…' : 'Pick an option to continue.'}
      </p>
      <div className="mt-4 h-1 w-[min(760px,92vw)] overflow-hidden rounded-full bg-white/10">
        <div className="h-full bg-primary transition-[width] duration-200" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

function ResultsView({ results, onDone }: { results: Results; onDone: () => void }) {
  const [left, setLeft] = useState(results.seconds || 10);
  useEffect(() => {
    const id = setInterval(() => setLeft((s) => (s <= 1 ? (clearInterval(id), onDone(), 0) : s - 1)), 1000);
    return () => clearInterval(id);
  }, []);
  const max = Math.max(1, ...results.counts);
  return (
    <div className="pointer-events-none absolute inset-0 flex items-center justify-center animate-flrp-in">
      <div className="w-[440px] max-w-[92vw] overflow-hidden rounded-lg border border-border bg-bg/95 shadow-xl shadow-black/50">
        <div className="flex items-center gap-2 border-b border-border-soft px-4 py-2.5">
          <Vote className="size-4 text-primary" />
          <span className="truncate text-[13px] font-bold">{results.title}</span>
          <span className="ml-auto text-2xs tabular-nums text-fg-faint">{results.total} vote{results.total === 1 ? '' : 's'}</span>
        </div>
        <div className="space-y-2 p-3">
          {results.options.map((o, i) => {
            const c = results.counts[i] ?? 0;
            const win = results.winner === i + 1 && results.total > 0;
            const pct = Math.round((c / (results.total || 1)) * 100);
            return (
              <div key={i}>
                <div className="mb-0.5 flex items-center gap-1.5 text-[13px]">
                  {win && <Trophy className="size-3.5 text-warning" />}
                  <span className={`truncate font-semibold ${win ? 'text-white' : 'text-fg-muted'}`}>{o}</span>
                  <span className="ml-auto tabular-nums text-fg-faint">{c} · {pct}%</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-panel">
                  <div className={`h-full rounded-full ${win ? 'bg-success' : 'bg-primary/60'}`} style={{ width: `${(c / max) * 100}%` }} />
                </div>
              </div>
            );
          })}
          {results.total === 0 && <div className="py-2 text-center text-xs text-fg-faint">No votes were cast.</div>}
        </div>
        <div className="border-t border-border-soft px-4 py-1.5 text-center text-2xs text-fg-faint">closing in {left}s</div>
      </div>
    </div>
  );
}
