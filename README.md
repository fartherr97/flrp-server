# FLRP Server — Florida Roleplay FiveM Foundation

Server foundation for **Florida Roleplay (FLRP)**, a vMenu-style FiveM roleplay
server with a lightweight persistent economy and a custom, centralized
permissions system driven by Discord membership.

> **Status:** Foundation build. See [`docs/BUILD_STATUS.md`](docs/BUILD_STATUS.md)
> for a component-by-component breakdown of what is complete, what needs
> configuration, and what is waiting on third-party assets.

---

## What FLRP is (and is not)

FLRP is **primarily a vMenu server**. It is **not** a traditional ESX/QB
economy server. We deliberately keep the freedom of vMenu and layer on only the
custom services we actually want:

- Persistent money (bank balance + transaction history)
- Persistent weapon ownership
- Hourly income, distributed in smaller active-time intervals
- Gun stores (for anyone not permitted to spawn weapons via vMenu)
- Discord-role-driven permissions
- Vehicle permissions
- Active playtime tracking (anti-AFK)
- Department duty states (BSO / FHP / MPD)
- Website-controlled permissions (later, via the existing FLRP Manager)

Everything above is built as **custom FLRP resources** (`flrp_*`) rather than by
installing a large roleplay framework.

## Law Enforcement Departments

The authoritative departments are:

- **BSO**
- **FHP**
- **MPD**

(Previous names such as HCSO / TPD are **not** used anywhere in this build.)

---

## Repository layout

```
server-data/
  server.cfg                 # top-level server config (includes config/*)
  config/                    # split, portable configuration
    server.cfg
    resources.cfg
    permissions.cfg          # base ACE hierarchy for vMenu / FLRP groups
    economy.cfg
    vehicles.cfg
    secrets.example.cfg      # template only — real secrets are gitignored
  resources/
    [dependencies]/          # oxmysql, etc. (installed per-host)
    [core]/                  # vMenu and other core community resources
    [flrp]/                  # custom FLRP resources (this repo's core work)
      flrp_core/             # shared services: identity, cache, exports
      flrp_access/           # Discord-gated connection deferrals
      flrp_permissions/      # centralized permission engine + ACE sync
      flrp_economy/          # persistent money, pay, transactions
      flrp_duty/             # server-authoritative department duty state
      flrp_weapons/          # weapon registry + persistent ownership
      flrp_gunstores/        # gun store purchase flow + NUI
      flrp_vehicles/         # vehicle registry + vehicle permissions
      flrp_api/              # HTTP contract for the FLRP Manager website
    [departments]/[bso] [fhp] [mpd]
    [vehicles]/ [maps]/ [eup]/ [standalone]/   # asset drop zones (later)

database/
  migrations/                # ordered, idempotent SQL migrations

docs/                        # architecture, ops, and integration docs
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the resources fit
together and why the boundaries are drawn where they are.

## Language

FLRP resources are written in **Lua**. FiveM's roleplay ecosystem
(`oxmysql`, vMenu, ACE) is Lua-first, which keeps us aligned with the
third-party resources we will import later. The `flrp_api` HTTP layer is
kept deliberately thin and could be reimplemented in Node if the FLRP Manager
integration ever needs it. Rationale is in `docs/ARCHITECTURE.md`.

---

## Getting started

1. Read [`docs/INSTALLATION.md`](docs/INSTALLATION.md) — installing FXServer,
   dependencies, and the database.
2. Copy `server-data/config/secrets.example.cfg` to `secrets.cfg` and fill in
   real values (guild ID, bot token, DB connection). **Never commit `secrets.cfg`.**
3. Configure Discord IDs in `server-data/config/permissions.cfg` and the
   convars documented in [`docs/DISCORD_INTEGRATION.md`](docs/DISCORD_INTEGRATION.md).
4. Run the database migrations in [`database/migrations/`](database/migrations/)
   (see [`docs/DATABASE.md`](docs/DATABASE.md)).
5. Start the server and validate against
   [`docs/BUILD_STATUS.md`](docs/BUILD_STATUS.md).

## Documentation index

| Doc | Purpose |
|-----|---------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, resource boundaries, data flow |
| [INSTALLATION.md](docs/INSTALLATION.md) | Standing up a dev/prod server |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Nodecraft → OVH/dedicated portability |
| [PERMISSIONS.md](docs/PERMISSIONS.md) | Groups, permission strings, ACE/vMenu |
| [DISCORD_INTEGRATION.md](docs/DISCORD_INTEGRATION.md) | Membership gate + role mapping |
| [ECONOMY.md](docs/ECONOMY.md) | Money, pay rates, intervals, anti-AFK |
| [WEAPONS.md](docs/WEAPONS.md) | Weapon registry, vMenu-spawn policy |
| [VEHICLES.md](docs/VEHICLES.md) | Vehicle registry + permissions |
| [DEPARTMENTS.md](docs/DEPARTMENTS.md) | BSO / FHP / MPD structure |
| [DATABASE.md](docs/DATABASE.md) | Schema, migrations, race-condition safety |
| [SECURITY.md](docs/SECURITY.md) | Threat model, server-side validation rules |
| [WEBSITE_INTEGRATION.md](docs/WEBSITE_INTEGRATION.md) | FLRP Manager API contract |
| [ASSET_IMPORT.md](docs/ASSET_IMPORT.md) | Importing third-party assets later |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues |
| [BUILD_STATUS.md](docs/BUILD_STATUS.md) | Live component status |

---

## Security posture (summary)

All FiveM clients are treated as untrusted. Money, prices, weapons,
permissions, department, duty state, certifications, vehicle eligibility, and
Discord identity are **always** validated server-side. See
[`docs/SECURITY.md`](docs/SECURITY.md).

## Git / mirroring

GitHub is the authoritative upstream; it is mirrored to a private Gitea server.
Do not force-push, rewrite history, or commit secrets.
