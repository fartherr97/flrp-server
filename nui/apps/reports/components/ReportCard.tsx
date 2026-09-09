import { MessageSquare } from 'lucide-react';
import type { Report } from '../types';
import { stamp } from '../lib';

const statusClass = (s: string) => (s === 'open' ? 'text-warning' : s === 'claimed' ? 'text-primary' : 'text-success');

export function ReportCard({ r, staff, onClick }: { r: Report; staff: boolean; onClick: () => void }) {
  const headline = staff ? r.reporter.name : (r.target ? `vs ${r.target}` : r.categoryLabel);
  return (
    <div className="v-card" onClick={onClick}>
      <p className="flex items-center gap-2">
        <span className="truncate text-sm font-semibold">{headline}</span>
        <span className="v-tag ml-auto shrink-0" style={{ color: r.categoryColour }}>{r.categoryLabel}</span>
      </p>
      <p className="mt-1 line-clamp-2 min-h-[2rem] text-xs leading-snug text-fg-muted">{r.description}</p>
      <div className="mt-2 flex items-center gap-1.5">
        <span className="v-tag opacity-70">#{r.id}</span>
        <span className={`v-tag font-semibold capitalize ${statusClass(r.status)}`}>{r.status}</span>
        {r.messages.length > 0 && <span className="v-tag inline-flex items-center gap-1 opacity-70"><MessageSquare className="size-3" />{r.messages.length}</span>}
        <span className="v-tag ml-auto opacity-50">{stamp(r.createdAt)}</span>
      </div>
    </div>
  );
}
