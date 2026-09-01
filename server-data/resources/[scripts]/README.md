# `[scripts]`

Drop zone for the **flrp-scripts** content repo (pCore + third-party escrowed
scripts: phone, radar, HUD, spawn, loading, taser, doorlock).

Cloned here by `deploy/assemble.sh` into a bracketed subfolder
(`[scripts]/[flrp-scripts]/…`). Contents are gitignored in the core repo; only
this README + `.keep` are tracked. See
[`docs/ASSET_INVENTORY.md`](../../../docs/ASSET_INVENTORY.md) and
[`docs/PCORE_INTEGRATION.md`](../../../docs/PCORE_INTEGRATION.md).

**pCore** is the identity / Discord gate / queue / permissions / vMenu authority
that FLRP builds on top of. It is `ensure`d in `config/resources.cfg`. Its FLRP
config rebrand is proposed in `integration/pcore/` (owner reviews + builds).
