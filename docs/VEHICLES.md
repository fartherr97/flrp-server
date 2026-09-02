# FLRP Vehicles

Centralized vehicle **registry** + server-authoritative spawn **permission**
engine (`flrp_vehicles`). Our real vehicle packs are not present yet — the
registry is intentionally **empty of real vehicles** and ready for import.

> **Do not invent the FLRP fleet.** The registry is populated from real imported
> vehicle resources (see [ASSET_IMPORT.md](ASSET_IMPORT.md)) or the FLRP Manager.

## Vehicle permissions

Conceptual permission strings (seeded in migration 008):

```
vehicle.bso.patrol   vehicle.bso.supervisor   vehicle.bso.command
vehicle.fhp.patrol    vehicle.fhp.supervisor    vehicle.fhp.command
vehicle.mpd.patrol    vehicle.mpd.supervisor    vehicle.mpd.command
vehicle.civilian.cert1  vehicle.civilian.cert2  vehicle.civilian.cert3
```

Granted to roles via `role_permissions` (see [PERMISSIONS.md](PERMISSIONS.md)).
Seeded defaults: department patrol → the department role; cert vehicles → the
matching cert tier (cert3 ⊇ cert2 ⊇ cert1); `director`(⇒`ownership`) → all.
Supervisor/command tiers are defined but granted to nobody by default pending a
department rank system.

## Registry (`vehicles` table)

| Field | Meaning |
|-------|---------|
| `spawn_name` | GTA/FiveM model name (e.g. `bso25tahoe`) — unique |
| `display_name` | e.g. "2025 BSO Tahoe" |
| `resource` | owning resource (set at import) |
| `department` | BSO / FHP / MPD / NULL(civilian) |
| `category` | Patrol / Supervisor / Command / Civilian / … |
| `min_rank` | minimum department rank (rank system TBD) |
| `certification` | civilian certification required (`roles.key`) |
| `required_permission` | primary permission required to spawn |
| `enabled` | on/off |
| `notes` | free text |

`vehicle_permissions` optionally lets a vehicle accept **any** of several
permissions (e.g. supervisor OR command) beyond the primary one.

Example row (illustrative — not seeded):

```
display_name: 2025 BSO Tahoe
spawn_name:   bso25tahoe
department:   BSO
category:     Patrol
required_permission: vehicle.bso.patrol
min_rank:     Deputy
enabled:      yes
```

## Spawn authorization (server-authoritative)

```lua
local ok, reason = exports.flrp_vehicles:CanSpawn(source, spawnName)
```

Resolution:

1. If `flrp_vehicles_enforce_permissions` is off → allow.
2. Unlisted spawn name → governed by `flrp_vehicles_allow_unlisted` (default
   `true` → defer to vMenu's own ACE; `false` → deny).
3. Listed + disabled → deny.
4. Certification gate (if set) must pass.
5. Permission gate: player must hold the primary `required_permission` **or**
   any `vehicle_permissions` entry. No requirement recorded → allowed.

The client helper `exports.flrp_vehicles:TrySpawn(spawnName)` asks the server
and spawns **only** on an authoritative allow. Any server-side spawn path (e.g.
a vMenu hook or a spawn menu) must consult `CanSpawn`.

### Exports

```lua
exports.flrp_vehicles:GetVehicle(spawnName)
exports.flrp_vehicles:CanSpawn(source, spawnName)     -- ok, reason
exports.flrp_vehicles:ListForPlayer(source)           -- vehicles this player may spawn
exports.flrp_vehicles:RegisterVehicle(tbl)            -- import/Manager upsert
exports.flrp_vehicles:ReloadRegistry()
```

## Importing vehicles later

When BSO/FHP/MPD vehicle packs arrive:

1. Place the resource in `[vehicles]`, `ensure` it in `config/resources.cfg`.
2. Use `tools/inventory_assets.mjs` to extract spawn names from `vehicles.meta`.
3. Register each model via `flrp_vehicles:RegisterVehicle` or the FLRP Manager,
   setting department, category, required permission, cert, and min rank.
4. `flrp_vehicles:ReloadRegistry()` (or `flrp_reload_vehicles`).

See [ASSET_IMPORT.md](ASSET_IMPORT.md) and
[WEBSITE_INTEGRATION.md](WEBSITE_INTEGRATION.md).
