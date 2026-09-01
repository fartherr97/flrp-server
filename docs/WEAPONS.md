# FLRP Weapons

> **Status:** pCore was evaluated and **dropped** (its source in `flrp-scripts`
> was incomplete and could not be built). FLRP runs its **own** Discord
> connection gate (`flrp_access`) and permission engine (`flrp_permissions`) —
> booted and verified with real players on a live server. This document
> describes that live design.

Weapon **registry** + persistent **ownership** (`flrp_weapons`) and the secure
gun-store purchase flow (`flrp_gunstores`).

## Weapon policy (authoritative)

Only these groups may spawn weapons **directly through vMenu**:

- **Certified Civilian III** (`cert_civ_3`)
- **Director** (`director`)
- **Ownership** (`ownership`)

**Everyone else** — normal civilians, Cert Civ I/II, BCSO, FHP, MPD, Moderator,
Administrator — must **buy weapons through gun stores**, unless the same player
also belongs to one of the three groups above.

This is enforced by the permission `weapon.vmenu.spawn`:

- **Default:** DENY
- **Allow:** `cert_civ_3`, `director`, `ownership`

The permission is **authoritative** (not just UI hiding). It is enforced two
ways so it holds even though vMenu is third-party:

1. **DB permission** `weapon.vmenu.spawn` (resolved by `flrp_permissions`) — the
   source of truth, editable via the FLRP Manager.
2. **ACE mirror** in `config/permissions.cfg` — vMenu's own weapon-spawn aces
   are denied to `builtin.everyone` and allowed only to `group.flrp.cert_civ_3`,
   `group.flrp.director`, `group.flrp.ownership`. `flrp_permissions` attaches
   each player to those groups dynamically, so vMenu itself refuses to spawn a
   weapon for anyone else.

### Still to connect after vMenu is installed

vMenu is not present in this foundation build. When you install it:

1. Confirm the exact vMenu ace names against your vMenu version and adjust
   `config/permissions.cfg` if they differ (we use `vMenu.WeaponSpawner.Menu`,
   `vMenu.WeaponSpawner.All`, `vMenu.WeaponOptions.Spawn`).
2. Confirm the player-principal syntax (`identifier.license:<lic>`) attaches to
   `group.flrp.*` correctly on your artifact (see `flrp_permissions/server/ace.lua`).
3. `ensure vMenu` in `config/resources.cfg`.
4. Verify in-game: a `cert_civ_1` player cannot open/use the vMenu weapon
   spawner; a `cert_civ_3`/`director`/`ownership` player can.

Tracked in [BUILD_STATUS.md](BUILD_STATUS.md) as *Weapon vMenu policy — NEEDS
RUNTIME TESTING (vMenu)*.

## Weapon registry

The `weapons` table is the model + **authoritative** price/eligibility source:

| Field | Meaning |
|-------|---------|
| `weapon_name` | canonical GTA/FiveM identifier (e.g. `WEAPON_PISTOL`) |
| `display_name` | shown to players |
| `enabled` | globally on/off |
| `gunstore_available` | buyable in gun stores |
| `price_cents` | **authoritative** price |
| `cert_required` | certification role required to buy (e.g. `cert_civ_2`) |
| `required_permission` | explicit permission required to buy |
| `vmenu_spawnable` | eligible for vMenu spawning (subject to `weapon.vmenu.spawn`) |
| `notes` | free text |

The **production catalog is not seeded**. Migration 008 adds a few clearly
labelled `[DEV]` entries for validation — remove them before production. The
real catalog is added at asset import or via the FLRP Manager.

### Exports

```lua
exports.flrp_weapons:GetWeapon(name)
exports.flrp_weapons:GetStoreCatalog()             -- display-safe list
exports.flrp_weapons:GetAuthoritativePrice(name)   -- server truth
exports.flrp_weapons:IsGunstoreAvailable(name)
exports.flrp_weapons:IsVMenuSpawnable(name)
exports.flrp_weapons:OwnsWeapon(source, name)
exports.flrp_weapons:GetOwnedWeapons(source)
exports.flrp_weapons:RecordOwnership(source, name, via, txId)
```

## Persistent ownership

Purchased/granted weapons are stored in `owned_weapons` (UNIQUE per
player+weapon) and re-applied to the player's ped on each spawn. FiveM cannot
stop an external mod menu from spawning weapons; that is a separate anti-cheat
concern (see [SECURITY.md](SECURITY.md)). What FLRP enforces is the **policy**:
weapons obtained *through FLRP* require ownership/authorization.

## Gun store purchase flow (server-authoritative)

The client may **display** a price, but the server fetches and validates the
authoritative price independently. `flrp_gunstores` runs 10 steps:

1. validate player   2. validate weapon (registry/enabled/available)
3. validate eligibility (certification)   4. validate permission
(`weapon.gunstore.purchase` + any weapon-specific permission)
5. fetch **authoritative** price   6. validate balance
7. **atomically** deduct money   8. record transaction (ledger)
9. record ownership   10. grant the weapon to the client

Plus: **server-side proximity** check (must be near the claimed store),
**idempotency key**, and a **per-source in-flight lock** to defeat
race/duplicate purchases. If ownership recording fails after charging, the
purchase is **auto-refunded**.

### Store locations

Configured as world coordinates in `flrp_gunstores/shared/config.lua` (no MLO
required). DEV placeholder locations are provided; edit/extend freely and update
them once map assets land. The NUI (`nui/`) is a clean, theme-aware panel.
