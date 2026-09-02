# FLRP Manager Integration

FLRP already has a management website (the **FLRP Manager**) in a **separate
repository**. This repo does **not** build a replacement UI. Instead it exposes
a backend/database/API contract (`flrp_api`) so the existing Manager can control
FiveM settings.

## Contract at a glance

- Transport: HTTP to the FXServer, routed to the `flrp_api` resource:
  `http(s)://<server-host>:<port>/flrp_api/<endpoint>`.
- Auth: header `X-FLRP-Secret: <flrp_api_shared_secret>` (from
  `config/secrets.cfg`). Constant-time compare; **fail-closed** when unset
  (503). Bad/missing secret → 401.
- Content type: JSON in, JSON out.
- Every **write** is recorded in `audit_logs` (`source = 'manager'`). The audit
  log is **read-only** through the API — it cannot be rewritten.
- Expose this behind the Manager's own network boundary / reverse proxy; the
  shared secret is the authenticator.

## Endpoints (representative, extensible)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | liveness + readiness |
| GET | `/permissions/matrix` | full role×permission matrix (resolved) |
| POST | `/permissions/role_permission` | set a role's effect for a permission |
| GET | `/roles` | list roles/departments |
| POST | `/discord_mappings` | map a Discord role ID → FLRP role |
| GET | `/economy/payrates` | list pay rates |
| POST | `/economy/payrates` | set a role's hourly pay |
| GET | `/config` | list runtime config |
| POST | `/config` | set a config key |
| GET | `/weapons` | list weapon registry |
| POST | `/weapons` | upsert a weapon (price/availability/cert/perm) |
| GET | `/vehicles` | list vehicle registry |
| POST | `/vehicles` | upsert a vehicle |
| GET | `/audit` | recent audit log (read-only) |

Add endpoints in `flrp_api/server/handlers.lua` following the same pattern
(register on the router, validate input, mutate, audit, hot-reload the relevant
cache).

## Example requests

```bash
# Read the permission matrix
curl -s http://HOST:30120/flrp_api/permissions/matrix \
  -H "X-FLRP-Secret: $SECRET"

# Flip weapon.vmenu.spawn for CivIII to deny
curl -s -X POST http://HOST:30120/flrp_api/permissions/role_permission \
  -H "X-FLRP-Secret: $SECRET" -H "Content-Type: application/json" \
  -d '{"roleKey":"cert_civ_3","permissionKey":"weapon.vmenu.spawn","effect":"deny"}'

# Set BSO hourly pay to $200
curl -s -X POST http://HOST:30120/flrp_api/economy/payrates \
  -H "X-FLRP-Secret: $SECRET" -H "Content-Type: application/json" \
  -d '{"roleKey":"bso","hourlyCents":20000}'
```

## What the Manager can control (backend ready now)

- **Permissions** — the matrix (`role_permissions`); flips take effect live via
  `ReloadPermissions()`.
- **Roles** — read; Discord role mappings (`discord_role_mappings`).
- **Vehicles** — registry upsert (display name, spawn, department, category,
  required permission, min rank, enabled).
- **Weapons** — registry upsert (price, availability, cert, permission,
  vmenu-spawnable).
- **Economy** — pay rates, pay interval + other keys via `/config`.
- **Departments** — via roles + permissions + duty (state is per-player, driven
  in-game).
- **Audit logs** — read.

### Future permission UI

The `/permissions/matrix` response is shaped exactly for a matrix editor:

```
{ roles: [...], permissions: [...], matrix: { [roleKey]: { [permKey]: bool } } }
```

The Manager renders Owner/Director/Admin/CivIII/BSO/FHP/MPD columns from this
and POSTs changes to `/permissions/role_permission`. No Lua changes needed.

### Future economy UI

`/economy/payrates` + `/config` back an editor for civilian/cert/department
hourly pay, the pay interval, weapon prices (`/weapons`), and weapon
availability. All values are DB-backed and hot-reloaded.

### Future vehicle UI

`/vehicles` upsert backs a form like *"2025 BSO Tahoe → spawn `bso25tahoe`,
department BSO, category Patrol, required permission `vehicle.bso.patrol`,
min rank Deputy, enabled"*. No invented fleet — populated from imported assets.

## Security

See [SECURITY.md](SECURITY.md). The shared secret is the boundary; keep it out
of Git, rotate as needed, and restrict who can reach the FXServer HTTP port.
