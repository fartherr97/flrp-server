import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Play, ScrollText, Info, ShieldCheck, Shield, Users, HeartPulse,
  Lock, MapPin, ArrowRight, ChevronLeft, ListChecks, AlignLeft,
} from 'lucide-react';
import { fetchNui, useNuiEvent, isBrowser, mockMessage } from '@flrp/components';

interface Header { title?: string; subtitle?: string; blurb?: string; tagline?: string; welcome?: string; welcomeA?: string; welcomeB?: string; flourish?: string }
interface Cat { id: string; label: string; tag?: string; blurb?: string; accent?: string; icon?: string }
interface Point { index: number; name: string; area?: string; desc?: string; image?: string; category: string; restricted?: boolean; allowed?: boolean }
interface UpdateItem { tag: string; color: string; title: string; hash?: string; by?: string; when?: string; body?: string }
interface Menu {
  updates?: { note?: string; items?: UpdateItem[] };
  about?: { title?: string; paragraphs?: string[]; stats?: { n: string; l: string }[] };
  leadership?: { subtitle?: string; groups?: { label: string; people: { n: string; t: string }[] }[] };
}
type View = 'play' | 'updates' | 'about' | 'leadership';

const CAT_ICON: Record<string, typeof Shield> = { shield: Shield, people: Users, cross: HeartPulse };
const ACCENT: Record<string, [string, string]> = { cyan: ['#33e1ff', '#12a8ff'], magenta: ['#ff2e95', '#ff5cc8'], ember: ['#ff7a3a', '#ff3b3b'] };
const hex2rgb = (h: string) => { h = h.replace('#', ''); return `${parseInt(h.slice(0, 2), 16)},${parseInt(h.slice(2, 4), 16)},${parseInt(h.slice(4, 6), 16)}`; };
const cvar = (o: Record<string, string>) => o as React.CSSProperties;

export function App() {
  const [open, setOpen] = useState(false);
  const [logo, setLogo] = useState('');
  const [header, setHeader] = useState<Header>({});
  const [player, setPlayer] = useState('');
  const [cats, setCats] = useState<Cat[]>([]);
  const [menu, setMenu] = useState<Menu>({});
  const [points, setPoints] = useState<Point[] | null>(null);
  const [view, setView] = useState<View>('play');
  const [catId, setCatId] = useState<string | null>(null);
  const [sel, setSel] = useState<number | null>(null);
  const [spawning, setSpawning] = useState(false);
  const toastRef = useRef<HTMLDivElement>(null);
  const toastTimer = useRef<number | undefined>(undefined);

  useNuiEvent<{ logo: string; header: Header; categories: Cat[]; menu: Menu; playerName: string }>('open', (d) => {
    setLogo(d.logo || ''); setHeader(d.header || {}); setCats(d.categories || []); setMenu(d.menu || {}); setPlayer(d.playerName || '');
    setOpen(true); setPoints(null); setView('play'); setCatId(null); setSel(null); setSpawning(false);
  });
  useNuiEvent<{ points: Point[] }>('points', (d) => setPoints(d.points || []));
  useNuiEvent('denied', () => { permToast(); setSel(null); setSpawning(false); });
  useNuiEvent('close', () => setOpen(false));

  useEffect(() => {
    if (!isBrowser()) return;
    mockMessage('open', { logo: '../img/flrp-logo.png', header: MOCK_HEADER, categories: MOCK_CATS, menu: MOCK_MENU, playerName: '100 | Owner | Mike' });
    mockMessage('points', { points: MOCK_POINTS });
  }, []);

  const byCat = useMemo(() => {
    const m: Record<string, Point[]> = {};
    (points || []).forEach((p) => { (m[p.category] ||= []).push(p); });
    return m;
  }, [points]);

  const cat = cats.find((c) => c.id === catId) || null;
  const accentName = view === 'play' && cat ? (cat.accent || 'cyan') : 'cyan';
  useEffect(() => {
    document.documentElement.dataset.accent = view === 'play' && cat ? (cat.accent || '') : '';
  }, [view, cat]);

  const permToast = () => {
    const t = toastRef.current; if (!t) return;
    t.classList.remove('show'); void t.offsetWidth; t.classList.add('show');
    window.clearTimeout(toastTimer.current); toastTimer.current = window.setTimeout(() => t.classList.remove('show'), 1700);
  };
  const catLocked = (c: Cat) => { const ps = byCat[c.id] || []; return ps.length > 0 && ps.every((p) => p.restricted && !p.allowed); };
  const openCat = (c: Cat) => { if (catLocked(c)) return permToast(); setCatId(c.id); setSel(null); };
  const goPlay = () => { setView('play'); setCatId(null); setSel(null); };
  const selectLoc = (p: Point) => { if (p.restricted && !p.allowed) return permToast(); setSel(p.index); };
  const deploy = () => { if (sel == null) return; setSpawning(true); fetchNui('select', { index: sel }); };

  if (!open) return <div ref={toastRef} className="perm-toast"><Lock />Insufficient Permissions!</div>;

  const NAV: { id: View; label: string; icon: typeof Play }[] = [
    { id: 'play', label: 'Play', icon: Play },
    { id: 'updates', label: 'Updates', icon: ScrollText },
    { id: 'about', label: 'About Us', icon: Info },
    { id: 'leadership', label: 'Leadership', icon: ShieldCheck },
  ];

  return (
    <>
      <div className="bg" aria-hidden><div className="base" /><div className="sun" /><div className="haze" /><div className="tint" /><div className="bands" /><div className="vig" /></div>
      <div className="topbar">
        <div className="brandline">{header.title === 'FLRP' ? 'Florida Roleplay' : header.title || 'Florida Roleplay'}<small>A Higher Standard</small></div>
        <div className="whoami"><div className="n">{player || 'Player'}</div><div className="t">{header.tagline || 'Florida Roleplay'}</div></div>
      </div>

      <main className="app">
        <aside className="rail">
          {logo && <div className="badge"><img src={logo} alt="FLRP" /></div>}
          <div className="welcome">
            <div className="w1">{header.welcome || 'Welcome to FLRP'}</div>
            <div className="w2">{header.welcomeA || 'Active Community, '}<b>{header.welcomeB || 'Hybrid vMenu'}</b></div>
          </div>
          <nav className="menu">
            {NAV.map((n) => (
              <button key={n.id} className={view === n.id ? 'active' : ''} onClick={() => { setView(n.id); if (n.id === 'play') goPlay(); }}>
                <n.icon className="ico" /> {n.label}
                <ChevronRightIcon />
              </button>
            ))}
          </nav>
          {header.flourish && <div className="flourish"><span>{header.flourish}</span></div>}
        </aside>

        <section className="stage">
          {view === 'play' && !catId && <Categories cats={cats} byCat={byCat} catLocked={catLocked} catImage={(id) => (byCat[id] || [])[0]?.image} onOpen={openCat} />}
          {view === 'play' && cat && <Locations cat={cat} pts={byCat[cat.id] || []} sel={sel} onBack={() => setCatId(null)} onPick={selectLoc} />}
          {view === 'updates' && <Updates data={menu.updates} />}
          {view === 'about' && <About data={menu.about} />}
          {view === 'leadership' && <Leadership data={menu.leadership} />}
        </section>
      </main>

      {view === 'play' && cat && (
        <div className={'deploy' + (sel != null ? ' show' : '')}>
          <div><div className="k">Deploy to</div><div className="v">{(byCat[cat.id] || []).find((p) => p.index === sel)?.name || '—'}</div></div>
          <button className="go" onClick={deploy} disabled={spawning}>
            {spawning ? 'Spawning…' : 'Spawn Here'}<ArrowRight width={18} height={18} />
          </button>
        </div>
      )}
      <div ref={toastRef} className="perm-toast"><Lock />Insufficient Permissions!</div>
    </>
  );

  function Categories({ cats, byCat, catLocked, catImage, onOpen }:
    { cats: Cat[]; byCat: Record<string, Point[]>; catLocked: (c: Cat) => boolean; catImage: (id: string) => string | undefined; onOpen: (c: Cat) => void }) {
    const shown = cats.filter((c) => (byCat[c.id] || []).length > 0);
    return (
      <>
        <div className="stage-head">
          <div className="eyebrow">Select your spawn</div>
          <h1>{header.subtitle ? 'Choose your path' : 'Choose your path'}</h1>
          <p>{header.blurb || 'Same state, different stories. Pick a lane, then a location — the world reshapes around you.'}</p>
        </div>
        <div className="cards cats">
          {shown.map((c, i) => {
            const [c1, c2] = ACCENT[c.accent || 'cyan'] || ACCENT.cyan;
            const rgb = hex2rgb(c1); const Icon = CAT_ICON[c.icon || 'people'] || Users;
            const lk = catLocked(c); const n = (byCat[c.id] || []).length;
            return (
              <div key={c.id} className={'card' + (lk ? ' locked' : '')} style={cvar({ '--i': String(i) })} onClick={() => onOpen(c)}>
                <div className="art">
                  <img className="photo" src={catImage(c.id)} alt="" />
                  <div className="wash" style={{ background: `linear-gradient(160deg, rgba(${rgb},.4), transparent 60%), linear-gradient(0deg, rgba(6,9,20,.55), transparent 55%)` }} />
                  <div className="grad" /><span className="rail-glow" style={cvar({ '--c1': c1, '--c2': c2 })} />
                  <Icon className="cico" />
                  {lk && <div className="lockover"><Lock /><span>{c.label.split(' ')[0]} access required</span></div>}
                </div>
                <div className="body">
                  <h3>{c.label}</h3><div className="tag">{c.tag}</div>
                  <div className="desc">{c.blurb}</div>
                  <div className="foot"><MapPin className="pin" />{n} location{n === 1 ? '' : 's'}<ArrowRight className="arrow" width={18} height={18} /></div>
                </div>
              </div>
            );
          })}
        </div>
      </>
    );
  }

  function Locations({ cat, pts, sel, onBack, onPick }:
    { cat: Cat; pts: Point[]; sel: number | null; onBack: () => void; onPick: (p: Point) => void }) {
    const [c1, c2] = ACCENT[cat.accent || 'cyan'] || ACCENT.cyan; const rgb = hex2rgb(c1);
    const example = pts.some((p) => (p.desc || '').startsWith('EXAMPLE'));
    return (
      <>
        <button className="back" onClick={onBack}><ChevronLeft width={16} height={16} />All categories</button>
        <div className="stage-head"><div className="eyebrow">{cat.tag}</div><h1>{cat.label}</h1><p>{cat.blurb}</p></div>
        <div className="cards locs">
          {pts.map((p, i) => {
            const lk = !!(p.restricted && !p.allowed);
            return (
              <div key={p.index} className={'card' + (lk ? ' locked' : '') + (sel === p.index ? ' selected' : '')}
                style={cvar({ '--i': String(i) })} onClick={() => onPick(p)}>
                <div className="art">
                  <img className="photo" src={p.image} alt="" />
                  <div className="wash" style={{ background: `linear-gradient(160deg, rgba(${rgb},.34), transparent 60%), linear-gradient(0deg, rgba(6,9,20,.55), transparent 55%)` }} />
                  <div className="grad" /><span className="rail-glow" style={cvar({ '--c1': c1, '--c2': c2 })} />
                  {lk && <div className="lockover"><Lock /><span>Access required</span></div>}
                </div>
                <div className="body">
                  <h3>{p.name}</h3><div className="tag">{p.area}</div>
                  <div className="desc">{(p.desc || '').replace(/^EXAMPLE — replace coords\.\s*/, '')}</div>
                  <div className="foot"><MapPin className="pin" />Spawn point<ArrowRight className="arrow" width={16} height={16} /></div>
                </div>
              </div>
            );
          })}
          {example && <div className="note"><Info />Example stations — wire these to real coordinates in flrp_spawn.</div>}
        </div>
      </>
    );
  }

  function Updates({ data }: { data?: Menu['updates'] }) {
    const items = data?.items || [];
    return (
      <>
        <div className="stage-head"><div className="eyebrow">Updates</div><h1>Patch notes</h1>
          {data?.note && <div className="feed-src"><AlignLeft />{data.note}</div>}</div>
        <div className="feed">
          {items.map((u, i) => (
            <div key={i} className="fitem" style={cvar({ '--i': String(i), '--fc': u.color })}>
              <span className="frail" />
              <div className="fmain">
                <div className="ftop"><span className="ftag">{u.tag}</span><h4>{u.title}</h4>{u.hash && <span className="fhash">{u.hash}</span>}</div>
                {u.body && <div className="fbody">{u.body}</div>}
                <div className="fmeta">{u.by} · {u.when}</div>
              </div>
            </div>
          ))}
        </div>
      </>
    );
  }

  function About({ data }: { data?: Menu['about'] }) {
    return (
      <>
        <div className="stage-head"><div className="eyebrow">About Us</div><h1>{data?.title || 'A higher standard'}</h1></div>
        <div className="about">
          {(data?.paragraphs || []).map((t, i) => <p key={i} dangerouslySetInnerHTML={{ __html: t.replace(/Florida Roleplay/g, '<b>Florida Roleplay</b>').replace(/ten years/g, '<b>ten years</b>') }} />)}
          <div className="stats">{(data?.stats || []).map((s, i) => <div key={i} className="stat"><div className="n">{s.n}</div><div className="l">{s.l}</div></div>)}</div>
        </div>
      </>
    );
  }

  function Leadership({ data }: { data?: Menu['leadership'] }) {
    const initials = (n: string) => n.split(' ').map((x) => x[0]).join('').slice(0, 2).toUpperCase();
    return (
      <>
        <div className="stage-head"><div className="eyebrow">Leadership</div><h1>Command team</h1><p>{data?.subtitle || 'The people keeping the standard higher.'}</p></div>
        {(data?.groups || []).map((g, gi) => (
          <div key={gi} className="lead-sec">
            <div className="lead-label">{g.label}</div>
            <div className="leaders">{g.people.map((pn, i) => (
              <div key={i} className="lcard" style={cvar({ '--i': String(i) })}>
                <div className="lava">{initials(pn.n)}</div><div className="lname">{pn.n}</div><div className="lrole">{pn.t}</div>
              </div>
            ))}</div>
          </div>
        ))}
      </>
    );
  }
}

function ChevronRightIcon() {
  return <svg className="chev" width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4}><path d="M9 6l6 6-6 6" /></svg>;
}

// ---------------- dev mocks (browser only) ----------------
const MOCK_HEADER: Header = { title: 'FLRP', subtitle: 'SPAWN SELECTOR', blurb: 'Same state, different stories. Pick a lane, then a location — the world reshapes around you.', tagline: 'Florida Roleplay', welcome: 'Welcome to FLRP', welcomeA: 'Active Community, ', welcomeB: 'Hybrid vMenu', flourish: 'Miami' };
const MOCK_CATS: Cat[] = [
  { id: 'leo', label: 'LEO Spawn Points', tag: 'Serve · Protect · Florida', accent: 'cyan', icon: 'shield', blurb: 'Sworn law enforcement only. Report on duty at your agency, gear up and hit the road.' },
  { id: 'civ', label: 'Civilian Spawn Points', tag: 'Live · Work · Explore', accent: 'magenta', icon: 'people', blurb: 'Same state, different stories. Drop into the city, the suburbs or the coast.' },
  { id: 'fire', label: 'Fire / EMS Spawn Points', tag: 'Care · Respond · Save Lives', accent: 'ember', icon: 'cross', blurb: 'Fire Rescue and EMS. Post up at your station and run calls across the county.' },
];
const MOCK_MENU: Menu = {
  updates: { note: 'Live feed — mirrors the #updates Discord channel where Gitea posts every commit.', items: [
    { tag: 'New', color: '#33e1ff', title: 'Spawn selector — reimagined', hash: 'a1b2c3d', by: 'Dev Team', when: 'just now', body: 'Brand-new Miami spawn screen with role-gated lanes and live previews.' },
    { tag: 'Added', color: '#ff2e95', title: 'Sonoran Radio is live', hash: '6e8f3d8', by: 'Dev Team', when: 'today', body: 'In-game radio is back — channels, tones and the mobile repeater.' },
  ] },
  about: { title: 'A higher standard', paragraphs: ["Here at Florida Roleplay we've been playing FiveM for almost ten years."], stats: [{ n: '10 Yrs', l: 'Experience' }, { n: 'Miami', l: 'Based' }, { n: 'BSO·FHP·MPD', l: 'Departments' }, { n: 'Est. 2026', l: 'Florida Roleplay' }] },
  leadership: { subtitle: 'The people keeping the standard higher.', groups: [{ label: 'Ownership', people: [{ n: 'Jordan', t: 'Owner' }, { n: 'Mike', t: 'Owner' }, { n: 'Johnson', t: 'Owner' }] }, { label: 'Directorship', people: [{ n: 'Juan', t: 'Executive Director' }] }] },
};
const CIV = [
  ['Downtown Miami','Miami-Dade','legion.webp','Bayfront core — banks and the busiest civilian hub.'],
  ['South Beach','Miami Beach','delperro.jpg','Ocean Drive — the boardwalk and the pier.'],
  ['Coral Gables','Miami-Dade','vinewood.webp','Tree-lined estates and Miracle Mile.'],
  ['Coconut Grove','Miami-Dade','mirrorpark.webp','Leafy bayside neighbourhood and marinas.'],
  ['Jackson Memorial','Miami-Dade','pillbox.jpg','Civic Center medical district.'],
  ['Miami International','Miami-Dade','airport.webp','MIA — air ops and the Dolphin Expressway.'],
  ['Deerfield Beach','Broward County','paleto.jpg','Far-north coastal town and the pier.'],
  ['Davie','Broward County','sandyshores.webp','Western Broward ranches and open road.'],
  ['Homestead','South Dade','grapeseed.webp','Quiet Redland farming community.'],
] as const;
const MOCK_POINTS: Point[] = [
  ...CIV.map((c, i) => ({ index: i + 1, name: c[0], area: c[1], category: 'civ', allowed: true, image: `../img/${c[2]}`, desc: c[3] })),
  { index: 10, name: 'Miami PD Headquarters', area: 'Miami-Dade · MPD', category: 'leo', restricted: true, allowed: false, image: '../img/missionrow.webp', desc: 'City police HQ.' },
  { index: 11, name: 'BSO Davie District', area: 'Broward County · BSO', category: 'leo', restricted: true, allowed: false, image: '../img/sandyshores.webp', desc: 'Broward SO district station.' },
  { index: 12, name: 'FHP Troop E', area: 'Florida Turnpike · FHP', category: 'leo', restricted: true, allowed: false, image: '../img/grapeseed.webp', desc: 'Highway Patrol Troop E.' },
  { index: 13, name: 'Miami Fire Rescue HQ', area: 'Miami-Dade · MFR', category: 'fire', allowed: true, image: '../img/pillbox.jpg', desc: 'EXAMPLE — replace coords. Rescue 1 and the EOC.' },
  { index: 14, name: 'Station 4 — South Beach', area: 'Miami Beach', category: 'fire', allowed: true, image: '../img/delperro.jpg', desc: 'EXAMPLE — replace coords. Beachfront ALS.' },
  { index: 15, name: 'BSO Fire — Davie', area: 'Broward County', category: 'fire', allowed: true, image: '../img/sandyshores.webp', desc: 'EXAMPLE — replace coords. County ALS.' },
];
