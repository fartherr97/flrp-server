import { useEffect, useState } from 'react';
import { BarChart3, Trophy } from 'lucide-react';
import { Panel, EmptyState } from '@flrp/components';
import { req, dur } from '../lib';
import type { Analytics as A } from '../types';

export function Analytics() {
  const [a, setA] = useState<A | null>(null);
  useEffect(() => { req<A>('analytics').then((r) => r.ok && setA(r)); }, []);
  if (!a) return <EmptyState icon={<BarChart3 />} title="Crunching numbers…" />;
  const o = a.overall || {}, t = a.today || {};
  const rows = (a.staff || []).map((s) => ({ name: s.name, claims: +s.claims || 0, resolved: +s.resolved || 0,
    avg: s.avg_claim != null ? +s.avg_claim : null, fastest: s.fastest != null ? +s.fastest : null, avgRes: s.avg_resolve != null ? +s.avg_resolve : null }));
  const ranked = rows.filter((s) => s.claims >= a.minClaims && s.avg != null).sort((x, y) => (x.avg! - y.avg!));
  const unranked = rows.filter((s) => !(s.claims >= a.minClaims && s.avg != null)).sort((x, y) => y.claims - x.claims);
  const slowest = Math.max(1, ...rows.map((s) => s.avg || 0));
  const Stat = ({ label, value, sub, accent }: { label: string; value: string; sub: string; accent?: string }) => (
    <Panel className="relative overflow-hidden p-3"><span className={`absolute inset-y-0 left-0 w-0.5 ${accent || 'bg-primary'}`} />
      <div className="text-[10px] font-bold uppercase tracking-wider text-fg-faint">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div><div className="mt-0.5 text-2xs text-fg-muted">{sub}</div></Panel>
  );
  return (
    <div className="space-y-4 py-1">
      <h2 className="text-lg font-bold">Analytics</h2>
      <div className="grid grid-cols-4 gap-2.5">
        <Stat label="Open right now" value={String(a.open || 0)} sub={`${a.claimed || 0} being handled`} accent="bg-warning" />
        <Stat label="Avg time to claim" value={o.avg_claim != null ? dur(+o.avg_claim) : '—'} sub={`today: ${t.avgClaim != null ? dur(+t.avgClaim) : '—'}`} />
        <Stat label="Avg time to resolve" value={o.avg_resolve != null ? dur(+o.avg_resolve) : '—'} sub="after claim" />
        <Stat label="Resolved today" value={String(t.resolved || 0)} sub={`${t.reports || 0} today · ${o.resolved || 0}/${o.total || 0} all-time`} accent="bg-success" />
      </div>
      <Panel className="p-3.5">
        <div className="mb-2 flex items-center gap-2 text-2xs font-bold uppercase tracking-wider text-fg-faint"><Trophy className="size-3.5" />Fastest responders <span className="font-medium normal-case tracking-normal text-fg-faint/80">(avg time to claim · min {a.minClaims} claims)</span></div>
        {rows.length === 0 ? <EmptyState title="No claims recorded yet" hint="Rankings appear once staff start claiming reports." /> : (
          <table className="w-full text-[13px]">
            <thead><tr className="text-left text-[10px] font-bold uppercase tracking-wider text-fg-faint">
              <th className="w-9 py-1.5">#</th><th>Staff</th><th>Claims</th><th>Resolved</th><th className="w-1/4">Avg to claim</th><th>Fastest</th></tr></thead>
            <tbody>
              {ranked.map((s, i) => (
                <tr key={s.name} className="border-t border-border-soft tabular-nums hover:bg-panel-hover">
                  <td className={`py-2 font-bold ${['text-warning','text-fg-muted','text-amber-700'][i] || 'text-fg-faint'}`}>{['🥇','🥈','🥉'][i] || i + 1}</td>
                  <td className="font-semibold">{s.name}</td><td>{s.claims}</td><td>{s.resolved}</td>
                  <td><span className="font-bold">{dur(s.avg)}</span><div className="mt-1 h-1.5 overflow-hidden rounded bg-panel-hover"><span className={`block h-full rounded ${i === 0 ? 'bg-success' : 'bg-primary'}`} style={{ width: `${Math.max(4, Math.round(100 * s.avg! / slowest))}%` }} /></div></td>
                  <td>{s.fastest != null ? dur(s.fastest) : '—'}</td>
                </tr>
              ))}
              {unranked.map((s) => (
                <tr key={s.name} className="border-t border-border-soft tabular-nums opacity-70">
                  <td className="py-2 font-bold text-fg-faint">–</td><td className="font-semibold">{s.name}<span className="ml-1.5 text-2xs font-medium text-fg-faint">needs {a.minClaims - s.claims} more</span></td>
                  <td>{s.claims}</td><td>{s.resolved}</td><td>{s.avg != null ? dur(s.avg) : '—'}</td><td>{s.fastest != null ? dur(s.fastest) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
