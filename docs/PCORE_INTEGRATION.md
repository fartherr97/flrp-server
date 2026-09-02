# FLRP ⇄ pCore Integration

> **SUPERSEDED / pCore DROPPED.** pCore's source in `flrp-scripts` is incomplete
> (missing `src/*/modules/builders/*.ts`) so it can't be built, and the escrowed
> build is locked to the unavailable owner's account. FLRP now runs its **own**
> Discord gate (`flrp_access`) + permission engine (`flrp_permissions`). This
> document is kept for historical context only. See docs/PERMISSIONS.md and
> docs/DISCORD_INTEGRATION.md for the live design.


**Decision:** FLRP is built **on top of pCore**. pCore is the authority for
identity, the Discord connection gate, the queue, permission groups, and vMenu.
FLRP owns the persistent systems on top: economy, duty pay, gun stores, weapon
ownership, the DB registries, audit, and the website API.

This replaces FLRP's original `flrp_access` (retired) and repurposes
`flrp_permissions` into a thin **bridge** over pCore.

## Who owns what

| Concern | Owner |
|--------|-------|
| FiveM identity, Discord ID | pCore |
| Connection gate (must be in Discord) + queue | **pCore** (`flrp_access` retired) |
| Discord role → permission groups (+ inheritance) | **pCore** (`configs/playerPerms.ts`) |
| vMenu permissions / ACE | **pCore** (`add_principal` + `vMenu:RequestPermissions`) |
| Which groups may vMenu-spawn weapons | **pCore** `configs/weaponPerms.ts` |
| Vehicle spawn permissions (vMenu/spawn menu) | **pCore** `configs/vehiclePerms.ts` |
| Persistent money, pay, ledger, anti-AFK | **FLRP** `flrp_economy` |
| Department duty state + department pay | **FLRP** `flrp_duty` |
| Gun stores (buy weapons w/ money) + ownership | **FLRP** `flrp_gunstores` / `flrp_weapons` |
| DB registries (weapons/vehicles), audit, config | **FLRP** |
| Website/Manager API | **FLRP** `flrp_api` |
| Permission **matrix** for the website | **FLRP** `flrp_permissions` (DB) — see below |

## The bridge (how FLRP reads pCore permissions)

pCore, when it resolves a player, runs
`add_principal identifier.discord:<userId> <group>` for every group the player
holds. That makes the player's principal a **child** of each group principal, so
membership is testable **synchronously from Lua via ACE** — no async calls into
pCore, no edits to pCore code.

`config/permissions.cfg` declares one ace per pCore group → FLRP role:

```
add_ace group.ownership      flrp.role.ownership      allow
add_ace group.director       flrp.role.director       allow
add_ace group.administrator  flrp.role.administrator  allow
add_ace group.moderator      flrp.role.moderator      allow
add_ace group.member         flrp.role.member         allow
add_ace certciv1             flrp.role.cert_civ_1     allow
add_ace certciv2             flrp.role.cert_civ_2     allow
add_ace certciv3             flrp.role.cert_civ_3     allow
add_ace bso                 flrp.role.bso           allow
add_ace fhp                  flrp.role.fhp            allow
add_ace mpd                  flrp.role.mpd            allow
```

Because a player is a child of (say) `bso`, `IsPlayerAceAllowed(src,
'flrp.role.bso')` returns true. `flrp_permissions` builds the player's FLRP
role set from these checks, then resolves effective permissions against the DB
`role_permissions` matrix exactly as before. So:

- **Role membership** now comes from **pCore** (Discord-driven), not `flrp_access`.
- **What each role may do** (economy.manage, weapon.gunstore.purchase, the
  matrix for the website) still comes from the **FLRP DB** — unchanged, still
  Manager-editable.

This keeps the website-controlled permission matrix (`GetPermissionMatrix`,
`flrp_api`) working while pCore drives who is in which group.

> The bridge depends on pCore's group names. After the pCore rebrand (below),
> its groups are FLRP-aligned (`group.ownership`, `certciv3`, `bso`, …). If a
> group name changes, update the `add_ace` lines and the bridge map in
> `flrp_permissions/server/pcore.lua` together.

## What changed in FLRP

- **`flrp_access` — retired.** pCore owns the connection gate + queue. The
  resource stays in the repo marked DEPRECATED but is no longer `ensure`d.
- **`flrp_permissions` — bridged.** Role source is now pCore ACE (see
  `server/pcore.lua`); it no longer fetches Discord roles or attaches vMenu ACE
  principals (`ace.lua` retired — pCore owns vMenu). The DB matrix + resolver +
  `HasPermission`/`GetPermissionMatrix` are unchanged.
- **`config/permissions.cfg` — rewritten.** Now only the pCore→FLRP role ace
  bridge. The old vMenu weapon-spawn deny/allow block is **removed** (pCore's
  `weaponPerms` is the authority now).
- **Everything downstream is unchanged.** `flrp_economy`, `flrp_duty`,
  `flrp_gunstores`, `flrp_vehicles` still call
  `exports.flrp_permissions:HasPermission/IsInGroup`, which now resolves via
  pCore underneath.

## The FLRP weapon policy under pCore

The rule "only Cert Civ III / Director / Ownership may spawn weapons via vMenu;
everyone else buys at gun stores" is implemented in **pCore
`configs/weaponPerms.ts`**: weapons are granted to `certciv3` (⇒ director,
ownership by inheritance) and to nobody else. Players without weapon perms
simply can't vMenu-spawn, so they use FLRP gun stores (which grant persistent,
owned weapons independent of vMenu). See [WEAPONS.md](WEAPONS.md).

## The pCore rebrand (proposed — `integration/pcore/`)

pCore ships with SSRP config. FLRP needs BSO/FHP/MPD, FLRP Discord IDs, the
FLRP fleet, and FLRP branding. Because pCore is escrow-protected and owned by a
third party, the FLRP configs are provided as a **proposed replacement set**
under `integration/pcore/` for the pCore owner to review and build (`npm run
build`) — this repo never edits pCore directly. Files:

- `configs/discord.ts` — placeholders (bot token/guild via env, never committed)
- `configs/playerPerms.ts` — FLRP groups → **real Discord role IDs** (REPLACE_ME)
- `configs/vehiclePerms.ts` — FLRP groups → **real imported spawn names**
- `configs/weaponPerms.ts` — FLRP weapon policy (only certciv3/director/ownership)
- `configs/queue.ts` — FLRP branding/card

See `integration/pcore/README.md`.

## Open items

- **MPD** has no Discord group data or vehicles yet.
- Decide keep/replace for overlapping scripts: `nex-duty` vs `flrp_duty`,
  `nex-spawn`, HUD. Tracked in [BUILD_STATUS.md](BUILD_STATUS.md).
- pCore's permission model is **static TS config** (rebuilt on change), not
  DB-driven. Full website-driven permission editing would require either
  extending pCore to read the FLRP DB, or keeping role→permission mapping in the
  FLRP DB (current bridge) while group membership stays in pCore. Current design
  does the latter.
