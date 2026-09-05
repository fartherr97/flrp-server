// ==========================================================================
// FLRP :: flrp_spawn/tools/gen-art.mjs — generate spawn-card location art
// ==========================================================================
// Renders one original, stylised SVG per spawn location into ../img/ (a
// resource-level folder, NOT html/ — the NUI build wipes html/ every time).
// These are hand-parametrised vector scenes (skyline / desert / coast / etc.)
// in the FLRP palette — NOT real GTA screenshots — so they're ours to ship
// and depend on no external hosting. Re-run after editing:  node tools/gen-art.mjs
// ==========================================================================
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'img');
mkdirSync(OUT, { recursive: true });
const W = 800, H = 1200;

// ---- deterministic RNG (so re-runs are identical) ------------------------
function rng(seed) { let s = seed >>> 0; return () => (s = (s * 1664525 + 1013904223) >>> 0) / 4294967296; }
const rr = (r, a, b) => a + (b - a) * r();

// ---- primitives ----------------------------------------------------------
const sky = (top, mid, bot) => `
  <rect width="${W}" height="${H}" fill="url(#sky)"/>
  <defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${top}"/><stop offset=".55" stop-color="${mid}"/><stop offset="1" stop-color="${bot}"/>
  </linearGradient></defs>`;

function sun(cx, cy, r, color, glow = color) {
  return `<defs><radialGradient id="g${cx|0}"><stop offset="0" stop-color="${glow}" stop-opacity=".9"/>
    <stop offset="1" stop-color="${glow}" stop-opacity="0"/></radialGradient></defs>
    <circle cx="${cx}" cy="${cy}" r="${r*4}" fill="url(#g${cx|0})"/>
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="${color}"/>`;
}

function stars(seed, n, maxY, color = '#dfeaff') {
  const r = rng(seed); let s = '';
  for (let i = 0; i < n; i++) s += `<circle cx="${rr(r,0,W)|0}" cy="${rr(r,0,maxY)|0}" r="${rr(r,.5,1.6).toFixed(1)}" fill="${color}" opacity="${rr(r,.3,.9).toFixed(2)}"/>`;
  return s;
}

// smooth rolling hills / dunes as a filled bezier band
function hills(seed, baseY, amp, color, opacity = 1) {
  const r = rng(seed); let d = `M0 ${baseY}`; let x = 0;
  const step = 90;
  let prevY = baseY;
  for (; x <= W; x += step) {
    const y = baseY - rr(r, 0, amp);
    d += ` Q ${x - step/2} ${prevY - rr(r,-amp,amp)/2} ${x} ${y}`;
    prevY = y;
  }
  d += ` L ${W} ${H} L 0 ${H} Z`;
  return `<path d="${d}" fill="${color}" opacity="${opacity}"/>`;
}

// jagged mountain range
function mountains(seed, baseY, peak, color, opacity = 1) {
  const r = rng(seed); let d = `M0 ${baseY}`;
  for (let x = 0; x <= W; x += rr(r, 70, 130)) d += ` L ${x|0} ${(baseY - rr(r, peak*.3, peak))|0}`;
  d += ` L ${W} ${baseY} L ${W} ${H} L 0 ${H} Z`;
  return `<path d="${d}" fill="${color}" opacity="${opacity}"/>`;
}

// a city skyline row of buildings with optional lit windows
function skyline(seed, baseY, minH, maxH, color, { windows = false, win = '#ffd98a', winOp = .8 } = {}) {
  const r = rng(seed); let s = ''; let x = -20;
  while (x < W + 20) {
    const bw = rr(r, 34, 78), bh = rr(r, minH, maxH), bx = x, by = baseY - bh;
    s += `<rect x="${bx|0}" y="${by|0}" width="${bw|0}" height="${(bh+40)|0}" fill="${color}"/>`;
    if (windows) {
      for (let wy = by + 12; wy < baseY - 8; wy += 20)
        for (let wx = bx + 8; wx < bx + bw - 8; wx += 16)
          if (r() > .45) s += `<rect x="${wx|0}" y="${wy|0}" width="6" height="9" fill="${win}" opacity="${(winOp*rr(r,.5,1)).toFixed(2)}"/>`;
    }
    x += bw + rr(r, 2, 12);
  }
  return s;
}

function water(y, color, hl = '#ffffff') {
  let s = `<rect x="0" y="${y}" width="${W}" height="${H - y}" fill="${color}"/>`;
  for (let i = 0; i < 7; i++) s += `<rect x="${(rr(rng(i+1),0,W))|0}" y="${(y + 30 + i*30)}" width="${rr(rng(i*7+3),60,180)|0}" height="2" fill="${hl}" opacity="${(.10 - i*.01).toFixed(2)}"/>`;
  return s;
}

const pine = (x, y, s, c) => `<path d="M${x} ${y} l-${s*.55} ${s} h${s*1.1} Z M${x} ${y+s*.5} l-${s*.7} ${s} h${s*1.4} Z" fill="${c}"/><rect x="${x-2}" y="${y+s*1.4}" width="4" height="${s*.4}" fill="${c}"/>`;
const palm = (x, y, s, c) => {
  let f = '';
  for (let a = -70; a <= 70; a += 28) f += `<path d="M${x} ${y} q ${Math.cos(a*Math.PI/180)*s*.3} -${s*.4} ${Math.sin(a*Math.PI/180)*s} ${-Math.abs(Math.cos(a*Math.PI/180))*s*.35 + s*.1}" stroke="${c}" stroke-width="6" fill="none" stroke-linecap="round"/>`;
  return `<path d="M${x-3} ${y} q 6 ${s*.9} 2 ${s*1.5} l6 0 q 4 -${s*.6} -2 -${s*1.5} Z" fill="${c}"/>${f}`;
};

// bottom vignette so the card's title/footer text always reads
const vignette = () => `<rect width="${W}" height="${H}" fill="url(#vg)"/>
  <defs><linearGradient id="vg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#060a10" stop-opacity=".35"/><stop offset=".35" stop-color="#060a10" stop-opacity="0"/>
    <stop offset=".72" stop-color="#060a10" stop-opacity=".25"/><stop offset="1" stop-color="#060a10" stop-opacity=".9"/>
  </linearGradient></defs>`;

const wrap = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid slice">${body}${vignette()}</svg>`;

// ---- scene recipes -------------------------------------------------------
const scenes = {
  // Downtown Los Santos at dusk — dense lit skyline.
  legion: () => sky('#0b1e3a', '#3a2b57', '#b5544e')
    + sun(600, 300, 46, '#ffd27a', '#ff9d5c') + stars(11, 40, 260)
    + skyline(21, 820, 220, 380, '#101a2b', { windows: true, win: '#ffdf9e' })
    + skyline(22, 900, 320, 560, '#0a121e', { windows: true, win: '#8fd6e6', winOp: .5 }),

  // Pillbox medical district — a tall tower with a red cross, daylight.
  pillbox: () => sky('#2f6fb0', '#6fa9d8', '#d7ecff')
    + sun(180, 210, 40, '#fff7e0', '#ffffff')
    + skyline(31, 860, 180, 300, '#26445f')
    + `<rect x="330" y="360" width="150" height="540" fill="#1a3247"/>`
    + skyline(33, 900, 240, 380, '#16283a', { windows: true, win: '#bfe6ff', winOp: .5 })
    + `<rect x="378" y="430" width="54" height="18" fill="#e64b4b"/><rect x="396" y="412" width="18" height="54" fill="#e64b4b"/>`,

  // LSIA — control tower, runway lights, a plane on approach at dusk.
  airport: () => sky('#12294a', '#48507e', '#e6845c')
    + sun(640, 340, 38, '#ffe0a0', '#ff8f5a') + stars(41, 26, 300)
    + hills(42, 940, 30, '#182742')
    + `<g fill="#101c30"><rect x="120" y="640" width="26" height="300"/><rect x="96" y="600" width="74" height="60" rx="6"/></g>`
    + `<g stroke="#ffd98a" stroke-width="3" opacity=".9">${Array.from({length:8},(_,i)=>`<line x1="${300+i*18}" y1="${960-i*4}" x2="${520-i*10}" y2="${960-i*4}"/>`).join('')}</g>`
    + `<g fill="#0c1826" transform="translate(520 300) rotate(8)"><rect x="0" y="0" width="150" height="16" rx="8"/><path d="M40 8 l-40 -34 l12 0 l60 34 Z"/><path d="M40 12 l-30 30 l12 0 l48 -22 Z"/><rect x="120" y="-16" width="10" height="30" rx="4"/></g>`,

  // Mission Row PD — civic building + flag, cooler police-blue grade.
  missionrow: () => sky('#274b74', '#5b7fa6', '#c3d6e6')
    + skyline(51, 870, 160, 260, '#243a52')
    + `<g fill="#182a3d"><rect x="250" y="520" width="300" height="380"/><rect x="238" y="500" width="324" height="26"/></g>`
    + `<g fill="#0f1f2f">${Array.from({length:6},(_,i)=>`<rect x="${268+i*46}" y="530" width="20" height="360"/>`).join('')}</g>`
    + `<g stroke="#dfe9f2" stroke-width="5"><line x1="600" y1="470" x2="600" y2="900"/></g><path d="M600 480 h70 l-14 16 l14 16 h-70 Z" fill="#2f6fdc"/>`,

  // Sandy Shores — arid basin, dunes, water tower, a lone butte.
  sandyshores: () => sky('#7fb0c9', '#e9c98f', '#f3ddb0')
    + sun(150, 240, 52, '#fff2c8', '#ffe08a')
    + mountains(61, 720, 150, '#b98a63', .8)
    + hills(62, 900, 60, '#caa06f') + hills(63, 1000, 40, '#a97e52')
    + `<g stroke="#5c4632" stroke-width="7" fill="none"><path d="M150 900 l30 -150 M230 900 l-20 -150"/></g><ellipse cx="190" cy="740" rx="60" ry="34" fill="#6b513a"/>`
    + `<g fill="#3f5a2f"><path d="M560 900 v-46 M560 866 l-16 -14 M560 878 l18 -14"/></g><path d="M556 900 v-70 q4 -12 8 0 v70Z" fill="#3f5a2f"/>`,

  // Paleto Bay — foggy northern coast, pines, cold water.
  paleto: () => sky('#5b6f80', '#8ba0ad', '#c3d0d6')
    + mountains(71, 700, 200, '#3f5560', .9) + mountains(72, 820, 150, '#33454e')
    + Array.from({length:9},(_,i)=>pine(90+i*80, 760+ (i%2)*14, 46, '#22343b')).join('')
    + water(920, '#54727f')
    + `<rect x="0" y="640" width="${W}" height="200" fill="#c3d0d6" opacity=".18"/>`,

  // Grapeseed — farmland at morning, barn, silo, windmill.
  grapeseed: () => sky('#8ec4dc', '#cfe6d0', '#eef4d8')
    + sun(650, 200, 40, '#fff6d0', '#ffffff')
    + hills(81, 720, 70, '#7fae5c')
    + `<g>${Array.from({length:12},(_,i)=>`<path d="M0 ${840+i*26} L${W} ${820+i*26}" stroke="${i%2?'#8cbe63':'#7aab53'}" stroke-width="26"/>`).join('')}</g>`
    + `<g fill="#8a3b30"><path d="M120 900 v-120 h140 v120Z"/><path d="M110 782 l60 -46 l60 46Z"/></g><rect x="300" y="720" width="46" height="180" fill="#d9d2c4"/><ellipse cx="323" cy="720" rx="23" ry="16" fill="#b9b1a2"/>`
    + `<g stroke="#4a5a3a" stroke-width="6"><line x1="600" y1="900" x2="600" y2="700"/></g><g fill="#5a6d47" transform="translate(600 700)">${[0,72,144,216,288].map(a=>`<path transform="rotate(${a})" d="M0 0 L10 -60 L-10 -60 Z"/>`).join('')}</g>`,

  // Vinewood — golden-hour hills, mansion lights, a hillside sign.
  vinewood: () => sky('#213a63', '#8a5a6e', '#f0a35c')
    + sun(560, 360, 50, '#ffd27a', '#ff9a52') + stars(91, 30, 240)
    + mountains(92, 780, 220, '#2a2036', .95) + hills(93, 900, 70, '#1c1626')
    + Array.from({length:26},(_,i)=>`<rect x="${60+i*27}" y="${640+((i*53)%160)}" width="4" height="4" fill="#ffe9a8" opacity="${.5+((i*13)%5)/10}"/>`).join('')
    + `<g fill="#e9edf2" font-family="Arial Black, Arial" font-weight="900" font-size="52" opacity=".92"><text x="230" y="560" transform="skewX(-6)" letter-spacing="4">FLRP</text></g>`,

  // Del Perro — sunset beach, pier with a ferris wheel, palms.
  delperro: () => sky('#3a2f6b', '#c25a86', '#ffb057')
    + sun(400, 470, 60, '#ffd98a', '#ff7a52')
    + water(700, '#b25a7e', '#ffd0a0')
    + `<g stroke="#241a2c" stroke-width="8">${Array.from({length:10},(_,i)=>`<line x1="${120+i*60}" y1="720" x2="${120+i*60}" y2="900"/>`).join('')}<line x1="120" y1="720" x2="700" y2="720" /></g>`
    + `<g transform="translate(600 640)" stroke="#241a2c" stroke-width="5" fill="none"><circle r="70"/>${Array.from({length:12},(_,i)=>`<line x1="0" y1="0" x2="${Math.cos(i*Math.PI/6)*70|0}" y2="${Math.sin(i*Math.PI/6)*70|0}"/>`).join('')}<circle r="10" fill="#241a2c"/></g>`
    + palm(120, 900, 90, '#1c1622') + palm(700, 910, 80, '#1c1622'),

  // Mirror Park — daytime suburb around the lake.
  mirrorpark: () => sky('#4d86c4', '#8fb8dd', '#dcecf6')
    + hills(101, 720, 50, '#6fa663')
    + Array.from({length:6},(_,i)=>`<g transform="translate(${70+i*120} ${770+(i%2)*18})"><rect x="0" y="0" width="86" height="70" fill="${i%2?'#c9b79a':'#b8c3cc'}"/><path d="M-8 0 l51 -34 l51 34Z" fill="#8a4d3d"/></g>`).join('')
    + Array.from({length:7},(_,i)=>pine(60+i*110, 760, 40, '#2f5a3a')).join('')
    + water(900, '#5f93c0'),
};

// ---- write ---------------------------------------------------------------
let n = 0;
for (const [name, build] of Object.entries(scenes)) {
  writeFileSync(join(OUT, `${name}.svg`), wrap(build()).replace(/\n\s+/g, ''));
  n++; console.log('  ✓', `img/${name}.svg`);
}
console.log(`generated ${n} location scenes -> ${OUT}`);
