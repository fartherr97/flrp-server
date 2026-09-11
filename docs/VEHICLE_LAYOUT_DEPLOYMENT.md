# Vehicle category migration

Deploy together with flrp-vehicles branch organize-vehicle-categories and
flrp-scripts branch organize-vehicle-categories. Merge those branches and
the corresponding server startup branch only in a restart window.

The vehicles repo moves existing resource directories, so do not let content
sync apply its branch while the old resources are running. Stop the server,
update all three repos, pull Git LFS assets, apply 011_vehicle_resource_groups.sql,
then start FiveM and check ULC/resource startup logs. Reconnect for verification.
The migration changes registry resource ownership only; permissions and enabled
flags are retained. Preserve pre-deployment commit IDs for a coordinated rollback.

Vehicle startup is three quoted category ensures: [Civilian],
[Emergency Services], [Donator]. [Staff] remains commented, matching previous
startup. Do not enable archived _optional packs alongside the active variants.
