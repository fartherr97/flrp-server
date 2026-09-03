# FLRP NUI Style Guide

The single reference for building any Florida Roleplay in‑game interface (NUI).
Tell a developer or AI **"follow `docs/FLRP_NUI_STYLE_GUIDE.md`"** and what they
build will match everything else.

> TL;DR — dark slate, Inter, restrained. It should look like professional
> public‑safety / SaaS software built for FLRP, **not** a typical FiveM UI.

---

## 1. Stack

| Concern | Choice |
| --- | --- |
| Framework | **React 19 + TypeScript** |
| Build | **Vite** → one self‑contained `index.html` per resource (`vite-plugin-singlefile`) |
| Styling | **Tailwind CSS** via the shared preset (`nui/shared/tailwind-preset.cjs`) |
| Components | Shared **shadcn‑style** library in `nui/shared/components` |
| Icons | **Lucide** only. 14–20px. No Font Awesome, no other icon sets. |
| Fonts | **Inter** (loaded from Google Fonts, `system-ui` fallback) |

Everything lives in the `nui/` workspace. Each resource is an app under
`nui/apps/<name>`; `npm run build:<name>` compiles it into that resource's
`html/index.html`. **FiveM serves static files — the built `index.html` is
committed to the repo.** There is no build step on the server.

Small, passive overlays (a HUD counter, toasts) stay plain HTML/CSS but **must
still use these tokens** — see `flrp_dutycounter`, `flrp_notify`.

---

## 2. Design philosophy

Build it like internal software for a public‑safety agency: calm, dense enough
to be useful, obviously trustworthy. The game must stay visible — only cover the
screen when the interface genuinely needs it.

**Avoid:** excessive gradients · giant rounded cards · neon/glowing borders ·
heavy blur · huge drop shadows · GTA fonts · rainbow interfaces · giant black
transparent rectangles · pill‑button soup · glassmorphism · oversized elements ·
huge headers · animation for its own sake · inconsistent spacing between scripts.

**A note on blur:** `backdrop-filter: blur()` renders as a **solid black box** in
FiveM's CEF (the game isn't part of the page's backdrop). **Never use it.** Use a
solid, slightly translucent panel token instead.

---

## 3. Tokens (`nui/shared/tokens.css`)

CSS variables are the single source of truth; the Tailwind preset maps them to
utilities. Change branding here, everything follows.

| Token | Tailwind | Use |
| --- | --- | --- |
| `--flrp-bg` | `bg-bg` | app background |
| `--flrp-panel` / `--flrp-panel-hover` | `bg-panel` / `bg-panel-hover` | cards, rows |
| `--flrp-elevated` | `bg-elevated` | modals, popovers |
| `--flrp-border` / `--flrp-border-soft` | `border-border` / `border-border-soft` | ~white/10, ~white/6 |
| `--flrp-text` / `-muted` / `-faint` | `text-fg` / `text-fg-muted` / `text-fg-faint` | primary / secondary / tertiary |
| `--flrp-primary` | `text-primary` `bg-primary` | FLRP cyan/blue accent |
| `--flrp-success` `-warning` `-danger` `-info` | same | semantic only |

Radii: `rounded-sm` 6px (controls), `rounded` 8px (cards), `rounded-lg` 12px
(windows). Motion: `duration-DEFAULT` = 140ms. Never saturate the UI with accent
or semantic colour — they are for status, indicators, icons, and one primary
button.

---

## 4. Typography

Inter. Hierarchy, top to bottom: app title `text-lg font-bold` → section label
`text-2xs font-bold uppercase tracking-wider text-fg-faint` → body `text-[13px]`
→ muted `text-xs text-fg-muted`. Numbers that align use `tabular-nums`. No
oversized text; nothing above `text-xl` in‑game.

---

## 5. Components (`import { … } from '@flrp/components'`)

`Button` (variants: primary · secondary · ghost · outline · danger · success;
sizes sm/md) · `IconButton` · `Panel` / `Card` / `SectionLabel` · `Badge` /
`StatusIndicator` · `Input` / `Textarea` / `Field` · `Tabs` · `Modal` ·
`EmptyState` / `LoadingState` / `ErrorState` · `AppHeader` · `KeybindHint`.

Rules: buttons are compact (h-7/h-9), 6px radius, clear hover + disabled, no
glow. Cards use a 1px soft border + subtle panel fill — never floating giant
shadows. Inputs share height/radius/border and a `ring-primary/25` focus.
Lists/tables are **compact rows with hover**, not a card per row. Status badges
stay small (`text-2xs`). Modals are centered on `bg-elevated`, don't take the
whole screen unless necessary.

---

## 6. FiveM UX & integration

Preserve the Lua contract exactly — never rename events for cosmetics. Use the
shared bridge (`@flrp/components`): `useNuiEvent(action, fn)` for
`SendNUIMessage`, `fetchNui(cb, data, mock)` for `RegisterNUICallback`,
`useEscape(onClose)` for ESC. Always release focus on close (`SetNuiFocus(false,
false)` server side / the app calling the `close` callback). Never leave the NUI
stuck open or focused.

**Contextual sizing:** duty menu / vehicle selector / status pickers → only as
big as needed (`w-[520px]`). MDT / admin / records → larger app windows, still
not full‑screen unless the feature is the screen (e.g. the connect spawn
selector). Every app must lay out with flex/grid + max‑widths + `vh/vw` caps so
it holds at 1080p, 1440p, and ultrawide.

**Animation:** 140–160ms fade / small translate only (`animate-flrp-in`,
`animate-flrp-rise`, `animate-flrp-slide`). No bounce, zoom, or long transitions.

**Errors & empty states:** never a blank panel. Every list has an `EmptyState`,
every fetch handles `{ ok:false, error }`, loading shows `LoadingState`.

**Dev mode:** `isBrowser()` is true only outside CEF; feed `mockMessage(...)` and
`fetchNui` mock args so the app runs in a normal browser. Mock code must never
affect in‑game behaviour.

---

## 7. Good vs bad

✅ compact slate panel, one primary button, Lucide icon at 16px, tabular numbers,
status as a small badge, game visible around a 520px window.
❌ full‑screen black rectangle, blurred glass, three gradients, a 28px neon
header, every row a rounded card, an emoji icon set, a bouncing modal.

---

## 8. Building a new FLRP interface

1. `nui/apps/<name>/` — copy an existing app's `vite.config.ts`,
   `tailwind.config.cjs`, `postcss.config.cjs`, `index.html`, `main.tsx`.
2. Write `App.tsx` with the shared components; talk to Lua only through the
   bridge; keep event names identical to the resource's existing contract.
3. Register the app in `nui/build.mjs` (name → resource folder).
4. `npm run build:<name>` → outputs the resource's `html/index.html`.
5. Point the resource `fxmanifest.lua` at `ui_page 'html/index.html'` and list
   only `files { 'html/index.html' }`. Commit source **and** the built file.
