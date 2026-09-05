import { useEffect, useRef, useState } from 'react';
import { MapPin, Lock, Play, ChevronLeft, ChevronRight, LoaderCircle } from 'lucide-react';
import { cn, fetchNui, useNuiEvent, isBrowser, mockMessage } from '@flrp/components';

interface Point { index: number; name: string; area?: string; desc?: string; image?: string; locked?: boolean }
interface Header { title?: string; subtitle?: string; blurb?: string; tagline?: string }


export function App() {
  const [open, setOpen] = useState(false);
  const [logo, setLogo] = useState('');
  const [header, setHeader] = useState<Header>({});
  const [playerName, setPlayerName] = useState('');
  const [points, setPoints] = useState<Point[] | null>(null);
  const [picking, setPicking] = useState<number | null>(null);
  const [focused, setFocused] = useState<number | null>(null);
  const [denied, setDenied] = useState<string | null>(null);
  const scroller = useRef<HTMLDivElement>(null);

  useNuiEvent<{ logo: string; header: Header; playerName: string }>('open', (d) => {
    setLogo(d.logo || ''); setHeader(d.header || {}); setPlayerName(d.playerName || '');
    setOpen(true); setPoints(null); setPicking(null); setFocused(null); setDenied(null);
  });
  useNuiEvent<{ points: Point[] }>('points', (d) => setPoints(d.points || []));
  useNuiEvent('denied', () => { setDenied('That location isn’t available to you.'); setPicking(null); });
  useNuiEvent('close', () => setOpen(false));

  useEffect(() => {
    if (!isBrowser()) return;
    mockMessage('open', { logo: '', header: MOCK_HEADER, playerName: 'Furkan Yücel' });
    mockMessage('points', { points: MOCK });
  }, []);

  // Fly the in-game camera to the first card as soon as the list arrives.
  useEffect(() => { if (points && points.length) focus(points[0].index); /* eslint-disable-line */ }, [points]);

  if (!open) return null;

  const focus = (index: number) => {
    setFocused((cur) => { if (cur !== index) fetchNui('focus', { index }); return index; });
  };
  const select = (p: Point) => { setPicking(p.index); setDenied(null); fetchNui('select', { index: p.index }); };
  const page = (dir: number) => scroller.current?.scrollBy({ left: dir * 360, behavior: 'smooth' });

  return (
    <div className="absolute inset-0 flex flex-col animate-flrp-in">
      {/* Dev only: a dim stand-in for the live game world behind glass cards. */}
      {isBrowser() && <div className="absolute inset-0 -z-20" style={{ background:
        'linear-gradient(160deg,#12222c 0%,#1a3540 40%,#3a2f28 100%)' }} />}

      {/* top + bottom scrim keeps header / footer text readable over the world */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-black/65 via-transparent to-black/60" />

      {/* ---- header ---- */}
      <header className="relative flex items-start justify-between px-[6vw] pt-[5vh] [text-shadow:0_1px_6px_rgba(0,0,0,.6)]">
        <div className="flex items-stretch gap-4">
          <span className="mt-1 w-[3px] rounded bg-primary/90" />
          <div>
            <h1 className="text-3xl font-extrabold uppercase tracking-tight leading-none">
              <span className="text-white">{header.title || 'FLRP'}</span>{' '}
              <span className="text-primary">{header.subtitle || 'SPAWN SELECTOR'}</span>
            </h1>
            <p className="mt-2 max-w-sm text-[13px] leading-snug text-white/70">
              {header.blurb || 'Choose where to drop in, or return to where you last logged off.'}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-right">
            <div className="text-sm font-semibold text-white">{playerName || 'Player'}</div>
            <div className="text-xs text-primary/90">{header.tagline || 'Florida Roleplay'}</div>
          </div>
          {logo && <img src={logo} alt="" className="size-11 rounded-lg object-cover ring-1 ring-primary/40" />}
        </div>
      </header>

      {denied && (
        <div className="relative mx-[6vw] mt-3 w-fit rounded-md border border-danger/50 bg-danger/20 px-3 py-1.5 text-xs font-medium text-white backdrop-blur">
          {denied}
        </div>
      )}

      {/* ---- carousel ---- */}
      <div className="relative flex flex-1 items-center gap-3 px-[3vw] min-h-0">
        <NavBtn onClick={() => page(-1)}><ChevronLeft className="size-7" /></NavBtn>

        {!points ? (
          <div className="flex flex-1 items-center justify-center gap-2 text-white/70">
            <LoaderCircle className="size-5 animate-spin" /> Loading locations…
          </div>
        ) : points.length === 0 ? (
          <div className="flex flex-1 items-center justify-center text-white/70">
            No spawn points available — contact staff.
          </div>
        ) : (
          <div ref={scroller}
            className="flex flex-1 gap-5 overflow-x-auto scroll-smooth py-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
            style={{ scrollSnapType: 'x mandatory' }}>
            {points.map((p) => (
              <Card key={p.index} p={p} isFocused={focused === p.index} picking={picking}
                onFocus={() => focus(p.index)} onPlay={() => select(p)} />
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
      className="relative grid size-11 shrink-0 place-items-center rounded-full text-white/60 backdrop-blur transition-colors hover:bg-white/10 hover:text-primary">
      {children}
    </button>
  );
}

function Card({ p, isFocused, picking, onFocus, onPlay }:
  { p: Point; isFocused: boolean; picking: number | null; onFocus: () => void; onPlay: () => void }) {
  const isPicking = picking === p.index;
  const dimmed = picking != null && !isPicking;

  return (
    <div onMouseEnter={onFocus}
      style={{ scrollSnapAlign: 'center' }}
      className={cn(
        'group relative flex h-[62vh] max-h-[520px] min-h-[400px] w-[300px] shrink-0 flex-col overflow-hidden rounded-2xl border transition-all duration-200',
        isPicking || isFocused ? 'border-primary ring-1 ring-primary/50' : 'border-white/15 hover:border-primary/60',
        dimmed && 'opacity-45',
      )}>

      {/* background: bundled location art if provided, else glass onto the live world */}
      {p.image ? (
        <div className="absolute inset-0 -z-10 bg-cover bg-center transition-transform duration-500 group-hover:scale-105"
          style={{ backgroundImage: `url("${p.image}")` }} />
      ) : (
        <div className={cn('absolute inset-0 -z-10 backdrop-blur-[2px] transition-colors',
          isFocused ? 'bg-white/[0.02]' : 'bg-black/35')} />
      )}
      {/* top scrim so the title + area read over bright photos/skies */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-28 bg-gradient-to-b from-black/75 via-black/25 to-transparent" />
      {/* the art already carries its own bottom vignette; glass cards need one added */}
      {!p.image && (
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-56 bg-gradient-to-t from-black/85 via-black/45 to-transparent" />
      )}

      {/* title */}
      <div className="relative flex items-center gap-3 p-5">
        <span className="grid size-11 place-items-center rounded-lg bg-primary text-primary-fg shadow-lg shadow-primary/30">
          {p.locked ? <Lock className="size-5" /> : <MapPin className="size-5" />}
        </span>
        <div className="leading-tight [text-shadow:0_1px_6px_rgba(0,0,0,.7)]">
          <div className="text-xl font-bold uppercase tracking-tight text-white">{p.name}</div>
          {p.area && <div className="text-[11px] font-medium uppercase tracking-widest text-primary/90">{p.area}</div>}
        </div>
      </div>

      {/* information + play */}
      <div className="relative mt-auto space-y-3 p-5">
        {p.desc && (
          <div className="rounded-md border-l-2 border-primary/70 bg-black/45 px-3 py-2 backdrop-blur-sm">
            <div className="text-[10px] font-semibold uppercase tracking-widest text-primary/80">Information</div>
            <p className="mt-0.5 text-[12px] leading-snug text-white/80">{p.desc}</p>
          </div>
        )}
        <button onClick={onPlay} disabled={picking != null}
          className={cn(
            'flex w-full items-center justify-center gap-2 rounded-md py-2.5 text-sm font-semibold backdrop-blur transition-colors',
            isPicking
              ? 'bg-primary text-primary-fg'
              : 'bg-white/15 text-white hover:bg-primary hover:text-primary-fg disabled:hover:bg-white/15 disabled:hover:text-white',
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
  { index: 1, name: 'Legion Square', area: 'Los Santos', image: '../img/legion.webp', desc: 'Downtown core — banks, shops and the busiest civilian hub.' },
  { index: 2, name: 'Pillbox Hill', area: 'Los Santos', image: '../img/pillbox.jpg', desc: 'Central medical district next to Pillbox Hospital.' },
  { index: 3, name: 'Mission Row PD', area: 'MPD — LEO only', image: '../img/missionrow.webp', desc: 'Mission Row police station. Sworn law enforcement only.', locked: true },
  { index: 4, name: 'Sandy Shores', area: 'Blaine County', image: '../img/sandyshores.svg', desc: 'Desert town in the county — Sandy SO and the trailer parks.' },
  { index: 5, name: 'Paleto Bay', area: 'Blaine County', image: '../img/paleto.svg', desc: 'The far-north coastal town, Paleto SO and the bank.' },
];
