# flrp_access — DEPRECATED (superseded by pCore)

**This resource is no longer used and is not `ensure`d.** It is kept in the repo
for reference only.

FLRP is built on top of **pCore**, which owns the Discord connection gate and
the queue (`playerConnecting` deferrals: must have Discord linked + be a guild
member, name validation, priority queue, adaptive card). Running both pCore and
`flrp_access` would mean two systems handling the same deferral — a conflict.

- Connection gate + Discord membership → **pCore**
- FLRP role membership is read from pCore via the ACE bridge →
  `flrp_permissions` (`config/permissions.cfg` + `server/pcore.lua`)

See [`docs/PCORE_INTEGRATION.md`](../../../../docs/PCORE_INTEGRATION.md).

If you ever run FLRP **without** pCore, this resource can be revived: re-add
`ensure flrp_access` to `config/resources.cfg` and restore the
`flrp_access:discordRolesResolved` handling in `flrp_permissions`. It is not
maintained for that path today.
