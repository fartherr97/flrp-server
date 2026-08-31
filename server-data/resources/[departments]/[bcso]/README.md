# `[bcso]` — BCSO

Department-specific resources for **BCSO** (Bay County Sheriff's Office).

This folder holds BCSO-specific glue (loadouts, vehicle registration hooks,
blips/patrol zones, duty helpers). It is intentionally minimal for now — most
behavior is centralized in the `[flrp]` services:

- **Permissions/roles:** `flrp_permissions` (role `bcso`, permissions `vehicle.bcso.*`)
- **Duty state + department pay:** `flrp_duty` + `flrp_economy`
- **Vehicles:** registered in the `flrp_vehicles` registry once BCSO vehicle
  packs are imported (see [`docs/ASSET_IMPORT.md`](../../../../docs/ASSET_IMPORT.md))
- **EUP/uniforms:** imported into `[eup]`

Create a `fxmanifest.lua` and `ensure flrp_bcso` in `config/resources.cfg`
only when this department needs its own runtime code. See
[`docs/DEPARTMENTS.md`](../../../../docs/DEPARTMENTS.md).
