# FLRP Asset Inventory (first import)

Snapshot of the content repos as of the first asset upload. Produced by
inspecting each repo (structure, escrow, Git LFS, manifests). Update this as
more assets land. See [ASSET_IMPORT.md](ASSET_IMPORT.md) for the process.

> **Note:** this inventory captures the *first upload*, when building on **pCore**
> was still on the table. pCore was later **dropped** (unbuildable source); FLRP
> runs its own `flrp_access` + `flrp_permissions`. The pCore notes below are
> historical.

## Repos

| Repo | State | Highlights |
|------|-------|-----------|
| `flrp-scripts` | **populated** | 12 escrowed resources incl. **pCore** (the core) |
| `flrp-vehicles` | **populated** | BSO + FHP packs (Git LFS); **no MPD yet** |
| `flrp-maps` | **populated** | 14 maps/MLOs (Git LFS) |
| `flrp-departments` | empty (README only) | — |
| `flrp-eup` | empty (README only) | — |

All asset repos use **Git LFS** for model files (`.ytd/.yft/.ydr/.ydd/.ybn`)
and ship **escrow-protected** (`.fxap`) resources. The deploy box must have
`git lfs` installed and LFS access to pull real model bytes (this analysis
session sees LFS files as pointer stubs).

## flrp-scripts (12 resources — all escrowed)

`pCore`, `lb-phone`, `lb-phoneprop`, `nex-duty`, `nex-hud`, `nex-loading`,
`nex-spawn`, `sonoran-radar`, `sonoran-radar_helper`, `smartsigns_sonoran`,
`SmartTaser`, `cd_doorlock`.

### pCore — the custom core (VikingTheDev / "Project Error")

A monolithic **TypeScript** FiveM resource (built with `npm run build` →
`dist/`, escrow-protected via `/assetpacks`). It currently carries **SSRP**
(Sunshine State Roleplay) configuration — old departments (TPD/HCSO/HCFR),
`discord.gg/ssrp`, SSRP fleet + donor tiers. It provides:

- **Connection gate + queue** on `playerConnecting` (Discord-linked required,
  name validation, priority queue, adaptive card).
- **Discord role → permission groups** with inheritance (`configs/playerPerms.ts`).
- **Vehicle permissions** per group + inheritance + `VehiclesBlockedForAI`
  (`configs/vehiclePerms.ts`).
- **Weapon permissions** per group + inheritance (`configs/weaponPerms.ts`).
- **vMenu integration** — sets ACE via `add_principal identifier.discord:<id>
  <group>` and fires `vMenu:RequestPermissions`.
- Exports: `getPlayerPerms`, `getPlayerRolesAndCategories`,
  `getPlayerDiscordRoles`, `getUserData`, `sendDiscordMessage/Embed`,
  `sendWebhookMessage/Embed`.

**Consequence:** pCore is the same layer as FLRP's `flrp_permissions` +
`flrp_access`. The initial decision was to build FLRP on top of pCore, but its
source proved incomplete/unbuildable, so pCore was **dropped** — FLRP keeps its
own `flrp_access` + `flrp_permissions` (live and verified). See
[PERMISSIONS.md](PERMISSIONS.md).

The other 11 are standalone third-party scripts (phone, radar, HUD, spawn,
loading, taser, doorlock). They integrate later as ordinary resources; several
overlap conceptually with FLRP (`nex-duty` vs `flrp_duty`, `nex-spawn`) and will
need a keep/replace decision — tracked in [BUILD_STATUS.md](BUILD_STATUS.md).

## flrp-vehicles

Git LFS. Layout is by department:

| Dept | Resource(s) | Spawn names |
|------|-------------|-------------|
| **BSO** | `HCSO21-24PPVSUVs` | `hcso1a`–`hcso1h` (8) |
| **FHP** | Badger Chargers (Full / Slick-Top+Subdued / Unmarked), Pursuit SUVs (Full / K9 / Slicktop+Subdued) | `hp1a`–`hp1l` (12), `hp2a`–`hp2p` (16) |
| **MPD** | — | none yet |

> Note: BSO spawn names still carry the **`hcso`** prefix (a repurposed HCSO
> pack). Keep the spawn names as-is (renaming a model means re-streaming), but
> register them under **BSO** in the FLRP vehicle registry. MPD has no vehicles
> yet.

These 44 spawn names seed the FLRP vehicle registry (migration
`009_seed_vehicles_flrp.sql`).

## flrp-maps (14 MLOs/maps — Git LFS)

`cfx-nteam-mrpd` (MRPD), the `[Prompt_Prison_Completed]` set (5 prison
interiors), `24paletobank_rsm_standalone`, `25paletosheriff_ext_rsm`,
`prompt_sandy_hospital`, `prompt_sandy_sheriff`, `ibonoja_senora_sheriff_station`,
`ibonoja_sa_training_center`, `cfx-nteam-river`, `meffle_yellowjack2`.

These are `ensure`d as ordinary resources once assembled. Gun-store locations in
`flrp_gunstores` can be re-pointed to these interiors later (e.g. an
Ammu-Nation-style interior) — currently world coordinates.

## Empty repos

`flrp-departments` and `flrp-eup` contain only their README — nothing to import
yet.
