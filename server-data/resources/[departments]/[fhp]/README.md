# `[fhp]` — FHP

Department-specific resources for **FHP** (Florida Highway Patrol).

This folder holds FHP-specific glue (loadouts, vehicle registration hooks,
blips/patrol zones, duty helpers). It is intentionally minimal for now — most
behavior is centralized in the `[flrp]` services:

- **Permissions/roles:** `flrp_permissions` (role `fhp`, permissions `vehicle.fhp.*`)
- **Duty state + department pay:** `flrp_duty` + `flrp_economy`
- **Vehicles:** registered in the `flrp_vehicles` registry once FHP vehicle
  packs are imported (see [`docs/ASSET_IMPORT.md`](../../../../docs/ASSET_IMPORT.md))
- **EUP/uniforms:** imported into `[eup]`

Create a `fxmanifest.lua` and `ensure flrp_fhp` in `config/resources.cfg`
only when this department needs its own runtime code. See
[`docs/DEPARTMENTS.md`](../../../../docs/DEPARTMENTS.md).
