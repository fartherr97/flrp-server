# FLRP Permissions

One centralized permission engine (`flrp_permissions`) answers **“may this
player do X?”**. No resource does its own Discord role checks.

## Concepts

- **Roles** (`roles` table) — FLRP groups. Four kinds:
  - `base` — `member` (every verified community member)
  - `staff` — `moderator → administrator → director → ownership` (inheritance)
  - `certification` — `cert_civ_1`, `cert_civ_2`, `cert_civ_3`
  - `department` — `bcso`, `fhp`, `mpd`
- **Permissions** (`permissions` table) — dotted strings, e.g.
  `weapon.vmenu.spawn`, `vehicle.bcso.patrol`, `staff.noclip`, `economy.manage`.
  Each has a `default_effect` (`allow`/`deny`) used when no role decides.
- **role_permissions** — grants/denies a permission to a role (`allow`/`deny`).
- **discord_role_mappings** — maps a Discord role ID to an FLRP role. Also
  bootstrappable from the `flrp_role_*` convars in `secrets.cfg`.
- **player_roles** — explicit per-player grants (staff overrides, temp roles).

## How a player gets their permissions

1. `flrp_access` reads the member's Discord role IDs during the connect gate.
2. Those IDs map to FLRP role keys (DB mappings + convar bootstrap), always plus
   base `member`, plus any `player_roles`.
3. Roles are **expanded via inheritance** (staff chain). `director` inherits
   `administrator` inherits `moderator` inherits `member`; `ownership` inherits
   `director`. (Inheritance flows upward — an administrator does **not** get a
   director's grants.)
4. Effective permission resolution, per permission key:
   - any explicit **`deny`** among the player's roles → **deny** (deny wins)
   - else any explicit **`allow`** → **allow**
   - else the permission's **`default_effect`**
   - else **deny**
5. The result is cached per player and mirrored into **ACE** so vMenu obeys it.

## Authoritative check (Lua)

```lua
if exports.flrp_permissions:HasPermission(source, 'weapon.gunstore.purchase') then ... end
exports.flrp_permissions:HasAnyPermission(source, { 'vehicle.bcso.supervisor', 'vehicle.bcso.command' })
exports.flrp_permissions:IsInGroup(source, 'cert_civ_3')
exports.flrp_permissions:GetRoles(source)                 -- { 'member', 'bcso', ... }
exports.flrp_permissions:GetEffectivePermissions(source)  -- { key = bool }
exports.flrp_permissions:GetPermissionMatrix()            -- for the FLRP Manager
```

## The permission matrix

`GetPermissionMatrix()` returns roles × permissions with each cell resolved
(inheritance + deny-beats-allow), which is exactly what the FLRP Manager renders:

```
                    Owner Director Admin CivIII BCSO FHP MPD
weapon.vmenu.spawn   YES    YES     NO    YES    NO  NO  NO
vehicle.bcso.patrol  YES    YES      -     -    YES   -   -
vehicle.fhp.patrol   YES    YES      -     -     -  YES   -
vehicle.mpd.patrol   YES    YES      -     -     -   -  YES
```

This matrix is **data**, not code — editing it (via `flrp_api` →
`role_permissions`) never touches Lua.

## Seeded matrix (migration 008)

- `weapon.vmenu.spawn` → allowed for `director` (⇒ `ownership`) and
  `cert_civ_3`. Denied by default for everyone else, so `administrator`,
  `moderator`, `bcso`, `fhp`, `mpd`, `cert_civ_1/2`, and normal civilians must
  use gun stores. This is the authoritative weapon policy — see [WEAPONS.md](WEAPONS.md).
- `weapon.gunstore.purchase` → `member` (everyone; still subject to per-weapon
  cert/permission checks).
- Department patrol vehicles → the department role; `director`(⇒`ownership`) can
  spawn all vehicles for management.
- Certification vehicles → the matching cert tier (cert3 ⊇ cert2 ⊇ cert1).
- `staff.noclip`, `staff.manage.players` → `moderator` (⇒ up the chain).
- `economy.manage`, `permissions.manage`, `vehicles.manage`, `weapons.manage`
  → `director` (⇒ `ownership`).

## ACE / vMenu integration

`config/permissions.cfg` declares the **stable** base ACE hierarchy
(`group.flrp.*`) and maps FLRP groups to vMenu aces. At runtime,
`flrp_permissions` attaches each connecting player's principal
(`identifier.license:<lic>`) to the right `group.flrp.*` groups and removes them
on disconnect — so **no player Discord ID is ever hand-added to the cfg**.

> After installing vMenu, verify the exact vMenu ace names and the license
> principal syntax against your vMenu/artifact version (see [WEAPONS.md](WEAPONS.md)).

## Reloading

- Console: `flrp_reload_perms` (in-game requires `permissions.manage`).
- `flrp_api` write endpoints call `ReloadPermissions()` automatically after
  changing role permissions or Discord mappings.
