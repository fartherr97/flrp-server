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

**STATICALLY VALIDATED + FIRST LIVE BOOT.** All Lua passes `luac -p` (syntax) and
`luacheck` (**0 warnings / 0 errors**, 49 files); NUI/tooling JS passes
`node --check`. Run it yourself: `./tools/validate.sh`.

**LIVE BOOT CONFIRMED (2026-09-01).** The full stack booted on a real FXServer +
MariaDB with real players connecting: license auth OK, one-file schema import
OK, the Discord gate verifying members by role, permissions resolving, economy
granting starting balances, every `flrp_*` resource reporting ready, and vMenu
enforcing the ACE weapon policy. Two runtime bugs surfaced and were fixed:
(1) oxmysql's Lua lib wasn't loaded and the shared `FLRP.DB`/`Logger`/`Util`
helpers weren't included across resources; (2) `flrp_permissions` lacked the ACE
grant to run `add_principal` at runtime. Systems below marked **LIVE** were
exercised end-to-end; the rest remain static-only until their in-game path runs.

**Deployment:** running on Nodecraft for the first boot; migrating to a
self-managed OVH VPS for a git-`pull` deploy workflow (see
[VPS_SETUP.md](VPS_SETUP.md)). Nodecraft stays up in parallel until the VPS is
proven.

## Status table

| Component | Status |
|-----------|--------|
| Core Architecture (flrp_core) | **LIVE** — boots, DB reachable, config loaded |
| Database schema + migrations | **LIVE** — `flrp_schema_full.sql` imported (19 tables), reachable |
| pCore | **DROPPED** — source in flrp-scripts is incomplete (missing `src/*/modules/builders/*.ts`), cannot be built; only the escrowed `.fxap` works and it is locked to the (unavailable) owner's account. FLRP runs its own gate/permissions instead. |
| Discord Access gate (flrp_access) | **LIVE** — verifying real members by Discord role on connect |
| Permissions engine (flrp_permissions) | **LIVE** — resolving real players' roles; `add_principal` ACE grant fixed |
| ACE / vMenu weapon policy | **LIVE** — vMenu installed + enforcing; set `vmenu_use_permissions true` |
| pCore FLRP config rebrand (integration/pcore/) | OBSOLETE (pCore dropped) — kept for reference only |
| Content repos (scripts/vehicles/maps) | POPULATED — NEEDS ASSEMBLE + RUNTIME TESTING |
| Vehicle registry seed (BCSO/FHP real spawns) | COMPLETE (migration 009) |
| MPD vehicles / departments / EUP content | NEEDS ASSETS (repos empty) |
| Duty system | **KEEP nex-duty**; `flrp_duty` rebuilt as a read-only adapter over nex-duty `duty_members` (configurable entity→dept map). COMPLETE (static) — NEEDS nex-duty setup + RUNTIME TESTING |
| nex suite (hud / loading / spawn / duty) | **KEEP** — owner is using the full nex suite (confirmed live). All ensured and running; sonoran-radar/SmartTaser/ulc/cd_doorlock also kept |
| Control plane | DECIDED: **florida-roleplay-site (Postgres)** is source of truth; pCore dropped; FLRP is the live permission authority |
| Live config sync — FLRP side (flrp_api) | COMPLETE (static) — `POST /sync` webhook + site pull + re-apply-to-online + background reconcile; NEEDS RUNTIME TESTING |
| Live config sync — site side | BUILT on `florida-roleplay-site` branch `claude/fivem-config-api` (GET /api/fivem/config + fivem_* tables + seed + edit endpoints + FXServer webhook + fivem.view/manage perms). NEEDS: merge, `db:init`, env vars, RUNTIME TESTING |
| Live config sync — site editor UI (React) | NEXT (build with site's client conventions loaded) |
| Economy (flrp_economy) | **LIVE** — granting starting balances; pay rates NEED seeding (roles:0) |
| Duty system (flrp_duty) | COMPLETE (static) — NEEDS RUNTIME TESTING |
| Anti-AFK / active playtime | COMPLETE (static) — NEEDS RUNTIME TESTING |
| Weapon registry + ownership (flrp_weapons) | COMPLETE (static); catalog NEEDS ASSETS (DEV rows only) |
| Gun stores (flrp_gunstores) | COMPLETE (static) — NEEDS RUNTIME TESTING |
| Vehicle registry + permissions (flrp_vehicles) | **LIVE** — 36 BCSO/FHP spawns loaded; more NEEDS ASSETS |
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
