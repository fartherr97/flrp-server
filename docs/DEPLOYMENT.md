# FLRP Deployment & Portability

FLRP must run identically on **Nodecraft** (initial host) and later on
**OVH/dedicated**. Nothing in this repo depends on Nodecraft-specific behavior.

## Portability principles

- All host-specific values live in `server-data/config/secrets.cfg` (gitignored)
  and the endpoint lines in `server-data/server.cfg`. Moving hosts changes only
  those.
- The database is external and reached by a connection string — not tied to any
  panel.
- No absolute paths, no panel-specific plugins, no host-locked scripts.
- OneSync settings are standard and portable (`config/server.cfg`).

## What changes per host

| Item | Where | Notes |
|------|-------|-------|
| Endpoint IP/port | `server-data/server.cfg` | `endpoint_add_tcp/udp` |
| `sv_licenseKey` | `config/secrets.cfg` | per-host keymaster key |
| DB connection | `config/secrets.cfg` | `mysql_connection_string` |
| Discord token/guild | `config/secrets.cfg` | same across hosts unless rotated |
| `sv_maxclients` | `config/server.cfg` | raise on stronger hardware |

## Nodecraft notes

- Upload `server-data/` contents; install FXServer via the panel's FiveM image.
- Set the start command to `+exec server.cfg`.
- Provide `secrets.cfg` through the panel's file manager or env → convar mapping;
  do not commit it.
- Ensure the DB (panel-provided or external) is reachable and migrations applied.

## Moving to OVH / dedicated

1. Provision the box, install FXServer artifacts.
2. Copy the repo + `secrets.cfg`.
3. Point `mysql_connection_string` at the (possibly migrated) database.
4. Update `endpoint_add_*` and firewall `30120/tcp+udp`.
5. Apply migrations (idempotent) against the target DB.
6. Start with `+exec server.cfg`.

Because state lives in the DB, a host move is: migrate DB → copy repo+secrets →
start. No code changes.

## Releases / mirroring

GitHub is the authoritative upstream, mirrored to a private Gitea server. Do not
force-push or rewrite history. Tag stable milestones; hosts deploy from a tag or
the default branch. Pin exact `oxmysql` / `vMenu` versions here when you settle
on them so hosts are reproducible.

## Backups

- Database: scheduled `mysqldump` (players, balances, transactions, ownership,
  audit are the critical tables). Store off-host.
- Config: `secrets.cfg` backed up **securely and separately** from the repo.
