# `[vehicles]`

Drop zone for imported **vehicle** resource packs (BCSO / FHP / MPD / civilian).

These are provided later via asset import and are **not** stored in Git (only
this README + `.keep` are tracked). See
[`docs/ASSET_IMPORT.md`](../../../docs/ASSET_IMPORT.md).

When a vehicle pack is imported:

1. Its resource folder is placed here.
2. It is `ensure`d in `config/resources.cfg`.
3. Each spawnable model is registered in the **vehicle registry** (DB `vehicles`
   table) with its department, category, and required permission — via the
   `flrp_vehicles:RegisterVehicle` export or the FLRP Manager / import tooling.

Do **not** invent the final fleet. The registry is populated from real imported
assets only. See [`docs/VEHICLES.md`](../../../docs/VEHICLES.md).
