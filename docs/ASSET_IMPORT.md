# FLRP Asset Import Workflow

The raw third-party FiveM assets (vehicles, maps/MLOs, EUP, scripts,
dependencies, paid/escrowed resources) are **not** in this repository yet. They
will be provided later in a separate directory, e.g. `../asset-imports/`. This
document defines the repeatable process to bring them in cleanly.

> Do **not** fabricate specific third-party resources. Until real assets arrive,
> registries stay empty/structural and store locations use world coordinates.

## When assets arrive

Given a directory like:

```
../asset-imports/
  vehicles/
  maps/
  eup/
  scripts/
  dependencies/
```

### 1. Inventory

Run the read-only inventory reporter:

```bash
node tools/inventory_assets.mjs ../asset-imports
# or machine-readable:
node tools/inventory_assets.mjs ../asset-imports --json > /tmp/inventory.json
```

It reports, per resource: manifest, category guess (vehicle / map-mlo / eup /
script / stream-asset), **escrow** detection (`.fxap` ⇒ paid/escrowed),
declared dependencies, best-effort **vehicle spawn names** (from
`vehicles.meta`), MLO/`.ymap` presence, duplicate resource names, and
cross-resource references. It never moves or edits anything.

### 2–11. Analyze

From the inventory, determine:

2. **Manifests** — confirm each resource has `fxmanifest.lua`/`__resource.lua`.
3. **Dependencies** — note `dependency`/`dependencies`; ensure each is available.
4. **Categorize** — vehicles → `[vehicles]`, maps → `[maps]`, EUP → `[eup]`,
   scripts → `[standalone]` or a department folder, deps → `[dependencies]`.
5. **Escrowed resources** — flagged (`.fxap`). Keep them intact; do not attempt
   to repackage escrowed code. Record which ones are escrowed.
6. **Vehicle spawn names** — collected from `vehicles.meta` `<modelName>`.
7. **MLOs / maps** — `.ymap` presence.
8. **EUP** — streamed ped components / uniform assets.
9. **Scripts** — Lua/JS/.net resources.
10. **Duplicates** — duplicate resource names (must be de-duplicated before
    ensuring, or FXServer will conflict).
11. **Resource-name references** — cross-resource `exports`/`TriggerEvent`
    references to wire dependencies correctly.

### 12. Integrate into `server-data/resources`

Move each resource into the correct `[...]` bucket. Preserve escrowed packaging.
Resolve duplicate names. Keep raw assets out of Git (the drop-zone folders'
contents are gitignored; the folder READMEs/`.keep` are tracked).

### 13. Update `config/resources.cfg`

Add `ensure <resource>` lines in dependency order (deps → maps/eup → vehicle
packs → department glue). Uncomment `ensure vMenu` once vMenu is installed.

### 14. Update the vehicle registry

For each vehicle model, register it in the `vehicles` table with department,
category, required permission, cert, and min rank — via
`exports.flrp_vehicles:RegisterVehicle{...}` (or the FLRP Manager). Then
`flrp_vehicles:ReloadRegistry()` / `flrp_reload_vehicles`. See
[VEHICLES.md](VEHICLES.md).

For weapons, populate the `weapons` registry with real display names, prices,
availability, cert, and permissions; remove the `[DEV]` seed rows. See
[WEAPONS.md](WEAPONS.md).

### 15. Update documentation + BUILD_STATUS

Record what was imported and flip the relevant rows in
[BUILD_STATUS.md](BUILD_STATUS.md) (e.g. *BSO Vehicle Import → COMPLETE*).

## Handoff format

When you (the team) provide assets, drop them under `../asset-imports/` (or tell
me the path) and say what each top-level folder contains. I will run the
inventory, propose a categorization + `resources.cfg` diff + registry entries,
and integrate after your review. Escrowed resources are kept intact and never
repackaged.

## Guardrails

- Never commit escrowed/paid assets or raw stream files to Git.
- Never invent spawn names, prices, or a fleet — derive them from the real
  assets.
- Keep the drop-zone `.gitignore` rules intact.
