# FLRP Live Config Sync (website-driven, no restart)

**Goal:** permission / group / vehicle / weapon / economy changes made on the
website take effect on the **live** server **immediately**, with **no restart**.

**Constraints that shape this design:**
- `florida-roleplay-site` (Express + **PostgreSQL**) is the **single source of
  truth** — it already models roles, a permission catalogue + grants,
  departments, and Discord role sync.
- FLRP owns identity and the connection gate itself (`flrp_access` +
  `flrp_permissions`) — no third-party core in the loop, so a config change
  never requires rebuilding or restarting anything.
- In-game permission checks must be **synchronous and fast** (every gun
  purchase, pay tick, spawn) — FLRP cannot HTTP-call the site per check.

## Roles in the new architecture

| Layer | Responsibility | Changes live? |
|-------|----------------|---------------|
| **florida-roleplay-site** (Postgres) | Source of truth: groups, Discord-role→group mappings, role→permission grants, vehicle/weapon access, pay rates | Yes — it's the editor |
| **`flrp_access`** (ours) | Identity + Discord connection gate; reads the member's Discord roles and hands them to `flrp_permissions` | Static (gate logic) |
| **FLRP** (`flrp_*`, ours) | **Live permission authority**: caches the site's config, resolves `HasPermission`, applies vMenu/ACE, economy/duty/gunstores | **Yes — reloads with no restart** |

`flrp_access` tells us *who the player is* and `flrp_permissions` attaches their
group principals from Discord roles. Everything the website edits **live** is
owned by FLRP, which re-applies to connected players instantly.

## Data flow

```
        edit in browser
             │
   florida-roleplay-site (Postgres)         ← source of truth
             │  (1) persist change
             │  (2) POST /sync  ───────────► flrp_api  (HTTP into FXServer)
             │      { kind, ids }                │
             │                                   │ (3) pull authoritative config
             ├───────  GET /api/fivem/config ◄───┤     for the changed scope
             │                                   │
             │                                   ▼
             │                         FLRP local cache (MySQL/in-memory)
             │                                   │ (4) re-resolve + re-apply to
             │                                   ▼     every ONLINE player NOW
             │                         ACE + vMenu:RequestPermissions +
             │                         flrp_permissions reload  (no restart)
```

1. Website persists the change in Postgres.
2. Website calls the FXServer **sync webhook** (`flrp_api` `POST /sync`, shared
   secret) telling FLRP *what* changed (permissions / mappings / vehicles /
   weapons / payrates).
3. FLRP pulls the authoritative config for that scope from the site's read API
   (`GET /api/fivem/config?scope=…`, shared secret) into its local cache.
4. FLRP re-resolves and **re-applies to all online players immediately**:
   - `flrp_permissions` rebuilds its store + re-resolves each connected source
     (already supported — `ReloadPermissions` + re-apply).
   - Capability ACEs it owns (e.g. `vMenu.*` weapon/vehicle spawn) are
     re-granted/revoked at the **group** level via `ExecuteCommand(add_ace/…)`,
     then `vMenu:RequestPermissions` is fired so vMenu re-reads — live.
   - Economy pay rates / config refresh from cache on the next tick.

No `restart`, no `ensure`, no resource reload. A missed webhook self-heals via a
low-frequency background pull (belt-and-suspenders).

## Why this is live / no-restart

FLRP resources apply permissions at **runtime** — the store is in memory, ACE is
applied with `ExecuteCommand`, and vMenu re-reads on an event. Re-resolving an
online player is just re-running the in-memory resolver + re-issuing ACE, which
FLRP already does on connect. Doing it again on a webhook is the same code path.
Nothing about a config change requires reloading a resource.

## The two contracts to build

### A. Site read API (on `florida-roleplay-site`)
`GET /api/fivem/config?scope=all|permissions|mappings|vehicles|weapons|payrates`
→ returns the FLRP-shaped config for that scope. Auth: shared secret
header. (Backed by the site's existing roles/permissions/department tables.)

### B. Site → FXServer sync webhook (on FLRP `flrp_api`)
`POST /sync  { scope, ids? }` → FLRP pulls scope from (A), updates cache,
re-applies to online players. Auth: shared secret. Returns `{ applied: n }`.

Plus FLRP background reconcile: pull `scope=all` every N minutes to catch missed
webhooks.

## The static cfg vehicle/weapon config

The static `config/permissions.cfg` vMenu/ACE rules are the **fallback/initial**
state only. The **live authority is FLRP**: it manages the group-level `vMenu.*`
(and FLRP capability) aces from the site config and fires
`vMenu:RequestPermissions`. Where FLRP asserts a capability ace, it wins live.

> Runtime nuance to confirm on a live box: exact `vMenu.*` ace names for your
> vMenu build, and that firing `vMenu:RequestPermissions` after an `add_ace`
> makes vMenu re-read for an online player. Verified during runtime testing.

## Build order

1. **FLRP side (this repo, buildable now):** the live re-apply engine + the
   `POST /sync` webhook in `flrp_api` + background reconcile. (Does not depend on
   the site's final schema — it pulls whatever the read API returns.)
2. **Site side (needs push access to `florida-roleplay-site`):** the
   `GET /api/fivem/config` read API + calling the FXServer webhook on save,
   backed by the site's existing perms/roles/department tables.
3. **Runtime test** end-to-end on a live box: edit on site → in-game within
   seconds, no restart.
