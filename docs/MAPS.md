# FLRP Maps & MLOs — fixing the "double map" overlay

When you streamed maps into the test server they showed **on top of** the
default GTA world — the new interior/props clipping through the original
buildings, doubled walls, z-fighting, floating geometry. This is the single
most common map-install problem and it is fixable. This doc explains why it
happens and the exact fix, so when a map lands in the `flrp-maps` repo (or you
send me the files) I can wire it in cleanly.

---

## Why the overlay happens

A GTA map location already has geometry there — the stock building, props,
collision. A custom map (MLO or YMAP) **adds** its geometry to the world; it
does **not** remove what was already there. So both render at once → the
overlay you saw.

Fixing it means the map must also **delete/hide the original world geometry**
at that spot. There are three mechanisms, and a correct map ships whichever it
needs:

1. **A deletion / "manual" YMAP** — an `*_manual.ymap` (or a ymap in an
   `entities` block with `LODtypes` / removed CEntityDef entries) that tells the
   engine "remove these stock entities here." Most MLOs from Tebex/GTA5-Mods
   include one. If it exists but isn't being loaded, you get overlay.
2. **An occlusion / IPL toggle** — some locations need a stock IPL disabled
   (e.g. an interior enabled and the shell removed) via client script
   `RemoveIpl` / `RequestIpl`. Big landmark MLOs use this.
3. **Correct manifest declarations** — if the map's own files aren't declared
   right in `fxmanifest.lua`, the game loads *some* of the map (the visible
   props) but not the deletion ymap, and again you get overlay.

90% of the time the map already contains the fix — it just wasn't declared or
loaded correctly. That's what #3 below is about.

---

## The correct `fxmanifest.lua` for a stream/YMAP map

A map resource that streams geometry must declare it as a map **and** stream its
assets. A minimal, correct manifest:

```lua
fx_version 'cerulean'
game 'gta5'

name 'flrp_map_example'
author 'FLRP'
description 'Example streamed map'
version '1.0.0'

-- Declares every .ymap in this resource as an actual world map (loads the
-- deletion/manual ymaps too, not just the props). THIS is the line whose
-- absence causes the overlay for ymap-based maps.
this_is_a_map 'yes'

-- If the map ships custom models/textures/collision, they live in stream/ and
-- are picked up automatically by data_file streaming. Custom ytyp archetypes
-- (interiors, custom props) MUST be registered:
data_file 'DLC_ITYP_REQUEST' 'stream/[name].ytyp'

files {
  'stream/**/*.ymap',
}
```

Key rules:

- **`this_is_a_map 'yes'`** — without it, ymaps are treated as loose files and
  the deletion ymap never applies. This is the usual culprit.
- **`data_file 'DLC_ITYP_REQUEST' 'path/to.ytyp'`** — one line **per** `.ytyp`.
  Missing this = invisible/untextured custom props, or the interior not sealing.
- Put stream assets (`.ydr .ydd .ytd .ybn .ymap .ytyp`) under a `stream/`
  folder; FiveM streams everything under `stream/` automatically — you do **not**
  list individual `.ydr`/`.ytd` files in `files{}`.
- For an **MLO** the interior itself is usually an escrowed `.rpf`/resource with
  its own manifest — don't repackage it; just `ensure` it in the right order.

## For MLOs that need an IPL toggle

If a map is a landmark replacement (e.g. a real interior at a stock building),
it may need a tiny client script instead of/alongside the ymap:

```lua
-- client.lua
CreateThread(function()
  RemoveIpl('stockInteriorIplName')   -- hide the stock shell
  RequestIpl('customInteriorIplName') -- enable the new interior
end)
```

The map's own README/product page names the IPLs. If you send me that, I wire it.

---

## Load order (in `config/resources.cfg`)

Maps go in the **content** section, after core/services. Order among maps
rarely matters, but a map that depends on a shared prop pack must start after
it. I add lines like:

```cfg
# --- Maps (from flrp-maps, synced into resources/[maps]) ---
ensure flrp_map_mrpd
ensure ibonoja_senora_sheriff_station
```

The `[maps]` drop zone is gitignored and populated by `deploy/sync-content.sh`
from the `flrp-maps` repo, same pattern as `[scripts]`.

---

## What I need from you to fix a specific overlay

Pick whichever is easiest:

**Option A — push it to `flrp-maps`** (best; use GitHub Desktop so Git LFS
handles the models). Then I clone it, read the manifest + file tree, and push
the corrected manifest / cfg entry.

**Option B — send me two things** for the offending map:
1. The map's `fxmanifest.lua` (copy/paste the whole file), and
2. Its folder file list — in the map folder run, and paste the output of:
   - Windows: `dir /s /b`
   - or just screenshot the folder tree showing where the `.ymap`, `.ytyp`,
     and any `_manual.ymap` / `stream/` folder are.

With either, I can tell you in one pass whether it's a missing
`this_is_a_map`, a missing `DLC_ITYP_REQUEST`, an unloaded deletion ymap, or an
IPL toggle — and fix it.

---

## Guardrails

- Never commit escrowed/paid map `.rpf`s or raw stream files to the main repo —
  they go in `flrp-maps` (with Git LFS), never here.
- Don't hand-edit `.ymap` binaries; fixes are in the manifest, cfg, or a small
  client script.
- Keep the `[maps]` drop-zone `.gitignore` rules intact.
