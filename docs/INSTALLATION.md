# FLRP Installation

Standing up an FLRP dev or production server. This is a **foundation** build;
some components need configuration or assets before they are fully live — see
[BUILD_STATUS.md](BUILD_STATUS.md).

## Prerequisites

- **FXServer** (cfx.re FiveM server artifacts) — install per-host into
  `server-data/` (the `alpine/`, `run.sh`/`FXServer.exe` etc. are gitignored).
- **MariaDB 10.5+ / MySQL 8+** reachable from the server.
- **oxmysql** installed into `server-data/resources/[dependencies]/oxmysql`.
- **vMenu** installed into `server-data/resources/[core]/vMenu` (can be added
  after first boot; FLRP publishes the ACE groups vMenu will consume).
- A **Discord bot** in your FLRP guild with the **Server Members Intent**
  enabled (for the membership gate).

## 1. Clone

```bash
git clone <repo-url> flrp-server
cd flrp-server
```

## 2. Database

Create the schema and apply migrations (idempotent, safe to re-run):

```bash
FLRP_DB_HOST=127.0.0.1 FLRP_DB_USER=flrp FLRP_DB_PASS=secret FLRP_DB_NAME=flrp \
  ./tools/apply_migrations.sh
```

Or apply `database/migrations/*.sql` in numeric order manually. See
[DATABASE.md](DATABASE.md).

## 3. Secrets

```bash
cp server-data/config/secrets.example.cfg server-data/config/secrets.cfg
```

Fill in `server-data/config/secrets.cfg` (it is **gitignored** — never commit
it):

- `sv_licenseKey` — from https://keymaster.fivem.net
- `mysql_connection_string` — e.g. `mysql://flrp:secret@127.0.0.1:3306/flrp`
- `flrp_discord_token`, `flrp_discord_guild_id`, `flrp_discord_invite_url`
- `flrp_role_*` — the real Discord role IDs (do **not** invent IDs)
- `flrp_api_shared_secret` — for the FLRP Manager API

See [DISCORD_INTEGRATION.md](DISCORD_INTEGRATION.md) for how to obtain each.

## 4. Dependencies / core resources

- Put `oxmysql` in `[dependencies]`.
- Put `vMenu` in `[core]` and uncomment `ensure vMenu` in
  `config/resources.cfg`.

## 5. Start

Point FXServer at `server-data/server.cfg`:

```bash
cd server-data
./run.sh +exec server.cfg    # or FXServer.exe +exec server.cfg on Windows
```

On boot you should see `flrp_core` report the database is reachable, then each
`flrp_*` resource log “ready”.

## 6. Verify

- `flrp_api` health (replace host/secret):
  ```bash
  curl -s http://127.0.0.1:30120/flrp_api/health -H "X-FLRP-Secret: <secret>"
  ```
- Connect with a client that is a verified member of the FLRP Discord — you
  should pass the deferral gate. A non-member should be denied.
- Console: `flrp_balance <serverId>` shows a player's balance.

## Dev shortcuts

- To bypass the Discord gate on a local dev box (no bot configured), set
  `set flrp_access_enabled false` — players connect with base `member` role
  only. **Never** do this in production.
- Run static validation any time: `./tools/validate.sh`.
