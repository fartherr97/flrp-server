# `[core]`

Core **community** resources that are not FLRP-authored but are central to the
server — most importantly **vMenu**.

## vMenu

FLRP is a vMenu-style server. Install vMenu here as `vMenu/`, then:

1. Uncomment `ensure vMenu` in [`config/resources.cfg`](../../config/resources.cfg).
2. Do **not** paste any player Discord IDs into `permissions.cfg`. FLRP assigns
   vMenu ACE groups dynamically at runtime (`flrp_permissions`), driven by
   Discord roles.
3. Verify the weapon-spawn policy: only `cert_civ_3`, `director`, and
   `ownership` may spawn weapons through vMenu. The base ACE mapping lives in
   [`config/permissions.cfg`](../../config/permissions.cfg); confirm the vMenu
   ace names against your vMenu version.

See [`docs/WEAPONS.md`](../../../docs/WEAPONS.md) for the exact vMenu wiring and
what still needs to be connected after vMenu is installed.

## Notes

- Keep FLRP custom code in `[flrp]`, not here.
- These resources are usually installed per-host and may be kept out of version
  control.
