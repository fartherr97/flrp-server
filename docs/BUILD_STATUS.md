# FLRP Build Status

Component-by-component status of the FLRP server foundation.

## Legend

- **COMPLETE** — built and statically validated; ready to use.
- **IN PROGRESS** — partially built.
- **BLOCKED** — cannot proceed without something.
- **NEEDS CONFIGURATION** — code done; needs real secrets/IDs to function.
- **NEEDS ASSETS** — waiting on third-party assets (vehicles/maps/EUP).
- **NEEDS RUNTIME TESTING** — code done + statically validated, but not yet
  exercised on a live FXServer + DB + Discord.

## Validation state (read this first)

**STATICALLY VALIDATED.** All Lua passes `luac -p` (syntax) and `luacheck`
(**0 warnings / 0 errors**, 47 files); NUI/tooling JS passes `node --check`. Run
it yourself: `./tools/validate.sh`.

**NOT RUNTIME TESTED.** No FXServer, MySQL/MariaDB, or Discord runtime testing
has been performed in this environment. Claims below are about code
completeness + static validation, **not** proof the live server works. Anything
touching the DB, Discord API, vMenu, or in-game behavior must be verified on a
real server before being trusted.

## Status table

| Component | Status |
|-----------|--------|
| Core Architecture (flrp_core) | COMPLETE (static) |
| Database schema + migrations | COMPLETE (static) — NEEDS RUNTIME TESTING (apply on real DB) |
| **pCore integration (build-on-top)** | COMPLETE (static) — NEEDS CONFIGURATION (rebrand build) + RUNTIME TESTING |
| Discord Access gate | **pCore owns it** — `flrp_access` RETIRED (deprecated in repo) |
| Permissions engine (flrp_permissions) | COMPLETE (static) — now bridged to pCore via ACE |
| ACE / vMenu weapon policy | **pCore `weaponPerms`** — NEEDS CONFIGURATION (rebrand) + RUNTIME TESTING |
| pCore FLRP config rebrand (integration/pcore/) | PROPOSED — NEEDS OWNER REVIEW + BUILD |
| Content repos (scripts/vehicles/maps) | POPULATED — NEEDS ASSEMBLE + RUNTIME TESTING |
| Vehicle registry seed (BCSO/FHP real spawns) | COMPLETE (migration 009) |
| MPD vehicles / departments / EUP content | NEEDS ASSETS (repos empty) |
| Duty system | **KEEP nex-duty**; `flrp_duty` rebuilt as a read-only adapter over nex-duty `duty_members` (configurable entity→dept map). COMPLETE (static) — NEEDS nex-duty setup + RUNTIME TESTING |
| Remove nex-hud / nex-loading / nex-spawn | DECIDED — remove from flrp-scripts (not `ensure`d); keep lb-phone, sonoran-radar, SmartTaser, cd_doorlock |
| Control plane | DECIDED: **florida-roleplay-site (Postgres)** is source of truth; pCore FROZEN (owner gone); FLRP is the live permission authority |
| Live config sync — FLRP side (flrp_api) | COMPLETE (static) — `POST /sync` webhook + site pull + re-apply-to-online + background reconcile; NEEDS RUNTIME TESTING |
| Live config sync — site side | BUILT on `florida-roleplay-site` branch `claude/fivem-config-api` (GET /api/fivem/config + fivem_* tables + seed + edit endpoints + FXServer webhook + fivem.view/manage perms). NEEDS: merge, `db:init`, env vars, RUNTIME TESTING |
| Live config sync — site editor UI (React) | NEXT (build with site's client conventions loaded) |
| Economy (flrp_economy) | COMPLETE (static) — NEEDS RUNTIME TESTING |
| Duty system (flrp_duty) | COMPLETE (static) — NEEDS RUNTIME TESTING |
| Anti-AFK / active playtime | COMPLETE (static) — NEEDS RUNTIME TESTING |
| Weapon registry + ownership (flrp_weapons) | COMPLETE (static); catalog NEEDS ASSETS (DEV rows only) |
| Gun stores (flrp_gunstores) | COMPLETE (static) — NEEDS RUNTIME TESTING |
| Vehicle registry + permissions (flrp_vehicles) | COMPLETE (static) — registry empty, NEEDS ASSETS |
| FLRP Manager API contract (flrp_api) | COMPLETE (static) — NEEDS CONFIGURATION (shared secret) |
| Audit logging | COMPLETE (static) |
| BCSO Vehicle Import | NEEDS ASSETS |
| FHP Vehicle Import | NEEDS ASSETS |
| MPD Vehicle Import | NEEDS ASSETS |
| Maps / MLOs | NEEDS ASSETS |
| EUP | NEEDS ASSETS |
| vMenu install + wiring | NEEDS CONFIGURATION / RUNTIME TESTING |
| Documentation | COMPLETE |
| Static validation tooling | COMPLETE |
| Multi-repo split + assembly (deploy/) | COMPLETE (scripts + docs) — NEEDS CONFIGURATION (create content repos + fill manifest) |
| Core `main` branch protection | NEEDS CONFIGURATION (run deploy/gitea_branch_protection.sh + replace CODEOWNERS teams) |

## What needs configuration before first live boot

1. `config/secrets.cfg` from the example — license key, DB connection, Discord
   token/guild/invite, `flrp_role_*` IDs, `flrp_api_shared_secret`. See
   [INSTALLATION.md](INSTALLATION.md) / [DISCORD_INTEGRATION.md](DISCORD_INTEGRATION.md).
2. Apply DB migrations against the real database.
3. Install `oxmysql` (`[dependencies]`) and `vMenu` (`[core]`).

## What needs runtime testing (after configuration)

- Connect gate allows verified members / denies non-members.
- Permissions resolve correctly; ACE groups attach; vMenu weapon spawner is
  restricted to `cert_civ_3` / `director` / `ownership`.
- Money: pay accrues only while active; debits are atomic; no double-charge on
  rapid purchases.
- Duty: `/duty` only works for held departments; department pay follows duty.
- Gun store: full purchase flow incl. proximity, price authority, ownership,
  refund-on-failure.
- API: auth, reads, audited writes, hot reload.

## What needs assets (blocked on third-party import)

- Real weapon catalog (replace `[DEV]` rows).
- Vehicle registry entries (BCSO/FHP/MPD/civilian) from imported packs.
- Maps/MLOs (and updating gun-store coordinates to match).
- EUP.

See [ASSET_IMPORT.md](ASSET_IMPORT.md).
