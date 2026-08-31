# FLRP Troubleshooting

## Boot / database

**`flrp_core` keeps logging “Waiting for database/schema…”**
- oxmysql not started or wrong connection string. Check `mysql_connection_string`
  in `secrets.cfg` and that `ensure oxmysql` runs before `flrp_core`.
- Migrations not applied — `schema_migrations` must exist. Run
  `./tools/apply_migrations.sh`.

**`flrp_core` ready but other resources never become ready**
- They wait on `exports.flrp_core:IsReady()`. If config never loads, the DB
  probe or `configuration` table is missing — re-check migrations.

## Connection gate (flrp_access)

**Everyone is denied at connect**
- `flrp_access_fail_open` is `false` (default) and Discord isn't configured or
  reachable. Set token/guild in `secrets.cfg`, or for a dev box set
  `flrp_access_enabled false`.
- Bot lacks **Server Members Intent** or isn't in the guild → API returns
  401/403. Check `[FLRP:ERROR][access]` logs.

**“No Discord account linked”**
- The player hasn't linked FiveM↔Discord. They must link the connection (Discord
  → Settings → Connections) and reconnect. See
  [DISCORD_INTEGRATION.md](DISCORD_INTEGRATION.md).

**Members with the right role are still denied**
- `flrp_role_community_member` doesn't match the real role ID, or the player
  lacks that role. Verify the ID (Developer Mode → Copy ID).

**Intermittent denials under load**
- Discord rate limiting (HTTP 429) → players get a “try again” message. Reconnect
  after a moment.

## Permissions / vMenu

**A player has the wrong permissions**
- Check `GetRoles`/`GetEffectivePermissions` via a debug command or the API
  matrix. Confirm the Discord role → FLRP role mapping (convar or
  `discord_role_mappings`). Run `flrp_reload_perms` after DB changes.

**Weapon spawning not restricted in vMenu**
- vMenu not installed yet, or its ace names differ from
  `config/permissions.cfg`. Verify against your vMenu version and confirm the
  player-principal syntax. See [WEAPONS.md](WEAPONS.md).

**Permission changes in the Manager don't apply**
- `flrp_api` calls `ReloadPermissions()` on write; if you edited the DB directly,
  run `flrp_reload_perms`.

## Economy

**Players aren't being paid**
- They may not be counted **active** (AFK): check `IsActive`. Ensure they're
  spawned and producing input; verify `economy.afk_timeout_seconds`.
- Pay rate is 0 for their role — check `pay_rates` / `flrp_reload_pay`.
- Not enough active time yet — pay lands once per `pay_interval_minutes` of
  active time.

**Balance seems wrong / double charge**
- Inspect `transactions` (append-only ledger, `balance_after_cents`). Idempotency
  keys prevent duplicates; a “missing” charge is usually an insufficient-funds
  debit that returned `insufficient_funds`.

## Gun stores

**“Too far from store”**
- Server proximity check failed — the player isn't near the claimed store's
  coordinates (`flrp_gunstores/shared/config.lua`). Update coords or move the
  player.

**Can't buy a weapon**
- Missing certification (`cert_required`), missing permission
  (`weapon.gunstore.purchase` or weapon-specific), not enough money, weapon
  disabled/not `gunstore_available`, or already owned. The NUI shows a reason.

## Vehicles

**Vehicle won't spawn / “not permitted”**
- Player lacks `required_permission` (or any `vehicle_permissions`) or the
  certification. If it's an unlisted model, `flrp_vehicles_allow_unlisted`
  governs it.

## API

**API returns 503 `api_not_configured`**
- `flrp_api_shared_secret` is unset/`REPLACE_ME`. Set it in `secrets.cfg`.

**API returns 401**
- Missing/incorrect `X-FLRP-Secret` header.

## Validation

**Not sure the code is syntactically sound**
- Run `./tools/validate.sh` (luac + luacheck + node --check). This is **static**
  validation only — it does not prove runtime behavior. See
  [BUILD_STATUS.md](BUILD_STATUS.md).
