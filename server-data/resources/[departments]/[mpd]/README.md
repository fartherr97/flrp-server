# `[mpd]` — MPD

Department-specific resources for **MPD** (Municipal Police Department).

This folder holds MPD-specific glue (loadouts, vehicle registration hooks,
blips/patrol zones, duty helpers). It is intentionally minimal for now — most
behavior is centralized in the `[flrp]` services:

- **Permissions/roles:** `flrp_permissions` (role `mpd`, permissions `vehicle.mpd.*`)
- **Duty state + department pay:** `flrp_duty` + `flrp_economy`
- **Vehicles:** registered in the `flrp_vehicles` registry once MPD vehicle
  packs are imported (see [`docs/ASSET_IMPORT.md`](../../../../docs/ASSET_IMPORT.md))
- **EUP/uniforms:** imported into `[eup]`

Create a `fxmanifest.lua` and `ensure flrp_mpd` in `config/resources.cfg`
only when this department needs its own runtime code. See
[`docs/DEPARTMENTS.md`](../../../../docs/DEPARTMENTS.md).
