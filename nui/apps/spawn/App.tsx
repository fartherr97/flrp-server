import { useEffect, useState } from 'react';
import { MapPin, Lock, ArrowRight, LoaderCircle } from 'lucide-react';
import { Badge, EmptyState, cn, fetchNui, useNuiEvent, isBrowser, mockMessage } from '@flrp/components';

interface Point { index: number; name: string; area?: string; locked?: boolean }

export function App() {
  const [open, setOpen] = useState(false);
  const [logo, setLogo] = useState('');
  const [points, setPoints] = useState<Point[] | null>(null);
  const [picking, setPicking] = useState<number | null>(null);
  const [denied, setDenied] = useState(false);

  useNuiEvent<{ logo: string }>('open', (d) => { setLogo(d.logo || ''); setOpen(true); setPoints(null); setPicking(null); setDenied(false); });
  useNuiEvent<{ points: Point[] }>('points', (d) => setPoints(d.points || []));
  useNuiEvent('denied', () => { setDenied(true); setPicking(null); });
  useNuiEvent('close', () => setOpen(false));
  useEffect(() => { if (isBrowser()) { mockMessage('open', { logo: '' }); mockMessage('points', { points: MOCK }); } }, []);

  if (!open) return null;
  const select = (p: Point) => { setPicking(p.index); setDenied(false); fetchNui('select', { index: p.index }); };

  return (
    <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-b from-black/50 via-black/25 to-black/60 p-8 animate-flrp-in">
      <div className="w-full max-w-[840px] animate-flrp-rise">
        <div className="mb-5 flex items-center gap-3">
          {logo && <img src={logo} alt="" className="size-11 rounded-lg object-cover ring-1 ring-border" />}
          <div>
            <h1 className="text-xl font-bold tracking-tight">Choose your spawn</h1>
            <p className="text-[13px] text-fg-muted">Select where you'd like to start your session.</p>
          </div>
          {denied && <Badge tone="danger" className="ml-auto">That location isn't available to you</Badge>}
        </div>

        {!points ? (
          <div className="flex items-center justify-center gap-2 py-16 text-fg-muted"><LoaderCircle className="size-5 animate-spin" />Loading locations…</div>
        ) : points.length === 0 ? (
          <EmptyState icon={<MapPin />} title="No spawn points available" hint="Contact staff if you can't spawn." />
        ) : (
          <div className="grid grid-cols-2 gap-2.5 md:grid-cols-3">
            {points.map((p) => (
              <button key={p.index} onClick={() => select(p)} disabled={picking != null}
                className={cn('group flex items-start gap-3 rounded-lg border p-3.5 text-left transition-colors',
                  picking === p.index ? 'border-primary bg-primary/15' : 'border-border-soft bg-panel hover:border-border hover:bg-panel-hover',
                  picking != null && picking !== p.index && 'opacity-50')}>
                <span className={cn('mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-md', picking === p.index ? 'bg-primary/20 text-primary' : 'bg-panel-hover text-fg-muted group-hover:text-primary')}>
                  <MapPin className="size-4" />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-1.5 font-semibold">{p.name}{p.locked && <Lock className="size-3 text-fg-faint" />}</div>
                  {p.area && <div className="truncate text-2xs text-fg-muted">{p.area}</div>}
                </div>
                <ArrowRight className={cn('mt-1 size-4 shrink-0 transition-transform', picking === p.index ? 'text-primary' : 'text-fg-faint group-hover:translate-x-0.5 group-hover:text-fg-muted')} />
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
const MOCK: Point[] = [
  { index: 1, name: 'Mission Row PD', area: 'Downtown · MPD HQ', locked: false },
  { index: 2, name: 'Paleto Sheriff', area: 'Paleto Bay · BSO North', locked: true },
  { index: 3, name: 'Sandy Shores', area: 'Blaine County', locked: false },
];
