# FLRP Architecture

> **Status:** pCore was evaluated and **dropped** (its source in `flrp-scripts`
> was incomplete and could not be built). FLRP runs its **own** Discord
> connection gate (`flrp_access`) and permission engine (`flrp_permissions`) —
> booted and verified with real players on a live server. This document
> describes that live design.

How the FLRP server foundation fits together, and why the boundaries are drawn
where they are.

## Goals

- Keep the **freedom of vMenu** while adding only the persistent systems we
  actually want (money, weapon ownership, permissions, duty, pay).
- **Not** an ESX/QB framework. FLRP is a small set of focused, custom resources
  (`flrp_*`) that communicate through documented exports/events.
- **Server-authoritative** everything that matters (money, permissions, prices,
  duty, eligibility). Clients are untrusted. See [SECURITY.md](SECURITY.md).
- Ready to **import third-party assets later** without rework
  ([ASSET_IMPORT.md](ASSET_IMPORT.md)) and to be **controlled by the existing
  FLRP Manager website** ([WEBSITE_INTEGRATION.md](WEBSITE_INTEGRATION.md)).

## Language choice: Lua

FLRP resources are Lua. FiveM's roleplay ecosystem — `oxmysql`, vMenu, ACE — is
Lua-first, and the third-party assets we will import are overwhelmingly Lua.
`flrp_api` is a thin HTTP layer that could be reimplemented in Node if the
Manager integration ever demanded it, but the core services stay in Lua for
consistency with everything around them.

## Resource map

```
[dependencies]  oxmysql (per-host)
[core]          vMenu + core community resources (per-host)

[flrp]
  flrp_core         identity, player cache, config, logging, audit, DB wrapper
  flrp_permissions  central permission engine + dynamic ACE/vMenu sync
  flrp_access       Discord-gated connection deferrals + role read
  flrp_economy      persistent money, ledger, role-based pay, anti-AFK
  flrp_duty         server-authoritative BSO/FHP/MPD duty state
  flrp_weapons      weapon registry + persistent ownership
  flrp_gunstores    secure purchase flow + NUI
  flrp_vehicles     vehicle registry + permission engine
  flrp_api          authenticated HTTP contract for FLRP Manager

[departments] [bso] [fhp] [mpd]   department-specific glue (minimal for now)
[vehicles] [maps] [eup] [standalone]   asset drop zones (imported later)
```

## Dependency direction (no cycles)

`flrp_core` depends only on `oxmysql`. **Everything else depends on
`flrp_core`** and never on each other at load time. Cross-resource
communication is one-directional and happens two ways:

1. **Lifecycle events emitted by `flrp_core`** (server-side only):
   - `flrp_core:playerLoaded (source, playerId, record)`
   - `flrp_core:playerDropped (source, playerId)`
   Each downstream resource loads/cleans up its own domain data on these.

2. **Runtime `exports`** — a resource calls another's documented export when it
   needs a decision (e.g. `flrp_gunstores` asks `flrp_permissions:HasPermission`
   and `flrp_economy:Debit`). These are runtime calls, not load-order deps, so
   there is no dependency cycle even though the graph is not a strict tree.

```
                 flrp_core  (identity/cache/config/log/db)
                    ▲  ▲  ▲  ▲  ▲  ▲  ▲
   ┌────────────────┘  │  │  │  │  │  └───────────────┐
 flrp_permissions  flrp_access  flrp_economy  flrp_duty  ...
       ▲   ▲                         │ (exports)
       │   └── flrp_duty ────────────┘
       └────── flrp_gunstores ── flrp_weapons ── flrp_economy (all via exports)
```

`flrp_access` reads Discord roles during the connect deferral and hands them to
`flrp_permissions` via the **server event** `flrp_access:discordRolesResolved
(license, roleIds)`. This keeps `flrp_access → flrp_permissions` a one-way,
event-based link (never a `RegisterNetEvent`, so a client can't inject roles).

## Request/decision flow examples

**Connect:** client connects → `flrp_access` deferral → resolve Discord ID →
Discord API guild-member check → verify Community Member role → read roles →
emit roles to `flrp_permissions` → allow → `flrp_core` loads persistent record
on `playerJoining` → `flrp_permissions` resolves effective permissions + syncs
ACE → `flrp_economy`/`flrp_duty`/`flrp_weapons` load their domain data.

**Buy a weapon:** client opens store near a configured location → server sends
display catalog → client clicks buy → server runs the authoritative 10-step
purchase (`flrp_gunstores` → `flrp_permissions` + `flrp_weapons` +
`flrp_economy`) → money deducted atomically → ownership recorded → weapon
granted. See [WEAPONS.md](WEAPONS.md).

## Source of truth

The **database** is the runtime source of truth for roles, permissions, the
permission matrix, pay rates, weapon/vehicle registries, duty state, config, and
audit logs. `config/*.cfg` convars are **fallbacks** used when a DB value is
absent, plus stable base ACE hierarchy. The FLRP Manager edits the DB (via
`flrp_api`); no Lua changes are needed to retune permissions, pay, prices, or
availability. See [DATABASE.md](DATABASE.md).
