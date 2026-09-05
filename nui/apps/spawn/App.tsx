import { useEffect, useRef, useState } from 'react';
import { MapPin, Lock, Play, ChevronLeft, ChevronRight, LoaderCircle } from 'lucide-react';
import { cn, fetchNui, useNuiEvent, isBrowser, mockMessage } from '@flrp/components';

interface Point { index: number; name: string; area?: string; desc?: string; image?: string; locked?: boolean }
interface Header { title?: string; subtitle?: string; blurb?: string; tagline?: string }

// Branded gradient fallbacks (slate/cyan/blue) used when a card has no image.
const FALLBACKS = [
  'linear-gradient(135deg, #0e2a3a 0%, #123044 55%, #0a1922 100%)',
  'linear-gradient(135deg, #12233d 0%, #163a5c 55%, #0b1626 100%)',
  'linear-gradient(135deg, #0f2e33 0%, #124a4a 55%, #08201f 100%)',
  'linear-gradient(135deg, #1a2438 0%, #24314f 55%, #0d1522 100%)',
];
// Top + bottom scrim so title (top) and body (bottom) stay readable over art,
// while the middle of the picture still shows through.
const SCRIM =
  'linear-gradient(to bottom, rgba(7,10,15,.68) 0%, rgba(7,10,15,.08) 30%, rgba(7,10,15,.42) 60%, rgba(7,10,15,.96) 100%)';

export function App() {
  const [open, setOpen] = useState(false);
  const [logo, setLogo] = useState('');
  const [header, setHeader] = useState<Header>({});
  const [playerName, setPlayerName] = useState('');
  const [points, setPoints] = useState<Point[] | null>(null);
  const [picking, setPicking] = useState<number | null>(null);
  const [denied, setDenied] = useState<string | null>(null);
  const scroller = useRef<HTMLDivElement>(null);

  useNuiEvent<{ logo: string; header: Header; playerName: string }>('open', (d) => {
    setLogo(d.logo || ''); setHeader(d.header || {}); setPlayerName(d.playerName || '');
    setOpen(true); setPoints(null); setPicking(null); setDenied(null);
  });
  useNuiEvent<{ points: Point[] }>('points', (d) => setPoints(d.points || []));
  useNuiEvent('denied', () => { setDenied('That location isn’t available to you.'); setPicking(null); });
  useNuiEvent('close', () => setOpen(false));

  useEffect(() => {
    if (!isBrowser()) return;
    mockMessage('open', { logo: '', header: MOCK_HEADER, playerName: 'Furkan Yücel' });
    mockMessage('points', { points: MOCK });
  }, []);

  if (!open) return null;

  const select = (p: Point) => { setPicking(p.index); setDenied(null); fetchNui('select', { index: p.index }); };
  const page = (dir: number) => scroller.current?.scrollBy({ left: dir * 360, behavior: 'smooth' });

  return (
    <div className="absolute inset-0 flex flex-col bg-[#05070b]/85 animate-flrp-in"
      style={{ backgroundImage: 'radial-gradient(120% 80% at 50% -10%, rgba(20,120,150,.14), transparent 60%)' }}>

      {/* ---- header ---- */}
      <header className="flex items-start justify-between px-[6vw] pt-[5vh]">
        <div className="flex items-stretch gap-4">
          <span className="mt-1 w-[3px] rounded bg-primary/80" />
          <div>
            <h1 className="text-3xl font-extrabold uppercase tracking-tight leading-none">
              <span className="text-fg">{header.title || 'FLRP'}</span>{' '}
              <span className="text-primary">{header.subtitle || 'SPAWN SELECTOR'}</span>
            </h1>
            <p className="mt-2 max-w-sm text-[13px] leading-snug text-fg-muted">
              {header.blurb || 'Choose where to drop in, or return to where you last logged off.'}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-right">
            <div className="text-sm font-semibold text-fg">{playerName || 'Player'}</div>
            <div className="text-xs text-primary/80">{header.tagline || 'Florida Roleplay'}</div>
          </div>
          {logo && <img src={logo} alt="" className="size-11 rounded-lg object-cover ring-1 ring-primary/40" />}
        </div>
      </header>

      {denied && (
        <div className="mx-[6vw] mt-3 w-fit rounded-md border border-danger/40 bg-danger/15 px-3 py-1.5 text-xs font-medium text-danger">
          {denied}
        </div>
      )}

      {/* ---- carousel ---- */}
      <div className="flex flex-1 items-center gap-3 px-[3vw] min-h-0">
        <NavBtn onClick={() => page(-1)}><ChevronLeft className="size-7" /></NavBtn>

        {!points ? (
          <div className="flex flex-1 items-center justify-center gap-2 text-fg-muted">
            <LoaderCircle className="size-5 animate-spin" /> Loading locations…
          </div>
        ) : points.length === 0 ? (
          <div className="flex flex-1 items-center justify-center text-fg-muted">
            No spawn points available — contact staff.
          </div>
        ) : (
          <div ref={scroller}
            className="flex flex-1 gap-5 overflow-x-auto scroll-smooth py-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
            style={{ scrollSnapType: 'x mandatory' }}>
            {points.map((p, i) => (
              <Card key={p.index} p={p} i={i} picking={picking} onPlay={() => select(p)} />
            ))}
          </div>
        )}

        <NavBtn onClick={() => page(1)}><ChevronRight className="size-7" /></NavBtn>
      </div>

      <div className="h-[5vh]" />
    </div>
  );
}

function NavBtn({ children, onClick }: { children: React.ReactNode; onClick: () => void }) {
  return (
    <button onClick={onClick}
      className="grid size-11 shrink-0 place-items-center rounded-full text-fg-faint transition-colors hover:bg-white/5 hover:text-primary">
      {children}
    </button>
  );
}

function Card({ p, i, picking, onPlay }: { p: Point; i: number; picking: number | null; onPlay: () => void }) {
  const isPicking = picking === p.index;
  const dimmed = picking != null && !isPicking;
  const art = p.image ? `${SCRIM}, url("${p.image}")` : `${SCRIM}, ${FALLBACKS[i % FALLBACKS.length]}`;

  return (
    <div style={{ scrollSnapAlign: 'center' }}
      className={cn(
        'group relative flex h-[62vh] max-h-[520px] min-h-[400px] w-[300px] shrink-0 flex-col overflow-hidden rounded-2xl border bg-cover bg-center transition-all duration-200',
        isPicking ? 'border-primary ring-1 ring-primary/50' : 'border-white/10 hover:border-primary/60',
        dimmed && 'opacity-45',
      )}>
      <div className="absolute inset-0 -z-10 bg-cover bg-center transition-transform duration-500 group-hover:scale-105"
        style={{ backgroundImage: art }} />

      {/* title */}
      <div className="flex items-center gap-3 p-5">
        <span className="grid size-11 place-items-center rounded-lg bg-primary text-primary-fg shadow-lg shadow-primary/30">
          {p.locked ? <Lock className="size-5" /> : <MapPin className="size-5" />}
        </span>
        <div className="leading-tight">
          <div className="text-xl font-bold uppercase tracking-tight text-white drop-shadow">{p.name}</div>
          {p.area && <div className="text-[11px] font-medium uppercase tracking-widest text-primary/90">{p.area}</div>}
        </div>
      </div>

      {/* information */}
      <div className="mt-auto space-y-3 p-5">
        {p.desc && (
          <div className="rounded-md border-l-2 border-primary/70 bg-black/40 px-3 py-2 backdrop-blur-sm">
            <div className="text-[10px] font-semibold uppercase tracking-widest text-primary/80">Information</div>
            <p className="mt-0.5 text-[12px] leading-snug text-fg-muted">{p.desc}</p>
          </div>
        )}
        <button onClick={onPlay} disabled={picking != null}
          className={cn(
            'flex w-full items-center justify-center gap-2 rounded-md py-2.5 text-sm font-semibold transition-colors',
            isPicking
              ? 'bg-primary text-primary-fg'
              : 'bg-white/10 text-white hover:bg-primary hover:text-primary-fg disabled:hover:bg-white/10 disabled:hover:text-white',
          )}>
          {isPicking ? <><LoaderCircle className="size-4 animate-spin" /> Spawning…</>
                     : <><Play className="size-4" /> Play</>}
        </button>
      </div>
    </div>
  );
}

const MOCK_HEADER: Header = {
  title: 'FLRP', subtitle: 'SPAWN SELECTOR',
  blurb: 'Choose where to drop in, or return to where you last logged off.',
  tagline: 'Florida Roleplay',
};
const MOCK: Point[] = [
  { index: 1, name: 'Legion Square', area: 'Los Santos', desc: 'Downtown core — banks, shops and the busiest civilian hub.' },
  { index: 2, name: 'Pillbox Hill', area: 'Los Santos', desc: 'Central medical district next to Pillbox Hospital.' },
  { index: 3, name: 'Mission Row PD', area: 'MPD — LEO only', desc: 'Mission Row police station. Sworn law enforcement only.', locked: true },
  { index: 4, name: 'Sandy Shores', area: 'Blaine County', desc: 'Desert town in the county — Sandy SO and the trailer parks.' },
  { index: 5, name: 'Paleto Bay', area: 'Blaine County', desc: 'The far-north coastal town, Paleto SO and the bank.' },
];
