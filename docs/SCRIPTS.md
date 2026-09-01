# FLRP Third-Party Scripts (flrp-scripts) — keep / remove

Decisions for the escrowed resources in the `flrp-scripts` content repo. See
[ASSET_INVENTORY.md](ASSET_INVENTORY.md).

| Resource | Decision | Notes |
|----------|----------|-------|
| ~~pCore~~ | **DROPPED** | Source in flrp-scripts was incomplete/unbuildable. FLRP runs its own `flrp_access` + `flrp_permissions` instead. See [PERMISSIONS.md](PERMISSIONS.md) / [DISCORD_INTEGRATION.md](DISCORD_INTEGRATION.md). |
| **nex-duty** | **KEEP (duty authority)** | Replaces `flrp_duty`'s own duty state. `flrp_duty` becomes a thin adapter (below). |
| nex-hud | **KEEP** | Owner is using the full nex suite (confirmed on live server). |
| nex-loading | **KEEP** | Owner is using the full nex suite (confirmed on live server). |
| nex-spawn | **KEEP** | Owner is using the full nex suite (confirmed on live server). |
| lb-phone (+ lb-phoneprop) | keep (unless you say otherwise) | standalone phone |
| sonoran-radar (+ helper) | keep | standalone radar |
| smartsigns_sonoran | keep | standalone |
| SmartTaser | keep | standalone |
| cd_doorlock | keep | standalone |

> Removal happens in the **flrp-scripts** repo (delete the folders / don't
> `ensure` them). This core repo can't push there; when you grant push access I
> can open a PR removing them, or you can delete them directly.

## Duty: `flrp_duty` → thin adapter over nex-duty

nex-duty owns duty (its `/duty` menu, entities, ranks, loadouts, blips,
livemap) and records the live on-duty roster in its own MySQL table
`duty_members (license, discord, entity, rank, callsign, …)` — same database as
FLRP (oxmysql).

Plan: **keep the `flrp_duty` export surface** (`GetDuty`, `IsOnDuty`, …) so
`flrp_economy` department pay is unchanged, but source the answer from nex-duty
instead of FLRP's own duty state:

```
exports.flrp_duty:GetDuty(source)
  -> SELECT entity, rank FROM duty_members WHERE license = <player license>
  -> map nex-duty `entity` id  ->  FLRP department (bcso/fhp/mpd)
  -> { department = 'BCSO'|'FHP'|'MPD'|nil, onDuty = row exists }
```

What this removes: FLRP's own duty state/persistence, the `/duty` command, and
the `player_duty_state` / `player_duty_log` writes (nex-duty keeps its own).
What it keeps: department pay in `flrp_economy` (still calls `flrp_duty:GetDuty`).

**Status: the adapter is BUILT** (`flrp_duty` v0.2.0). It reads nex-duty's
`duty_members` (matching on license or discord), maps the nex-duty **entity** to
an FLRP department, and reports `{ department, onDuty }`. It caches per player
(15s) and no-ops safely (everyone civilian) until nex-duty's table exists.

To finish once you set up nex-duty: name the BCSO/FHP/MPD entities, then set the
map. Defaults assume entity IDs `bcso` / `fhp` / `mpd`; override per department
in `secrets.cfg` / server.cfg if you name them differently:

```
set flrp_duty_entity_bcso "yourBcsoEntityId"
set flrp_duty_entity_fhp  "yourFhpEntityId"
set flrp_duty_entity_mpd  "yourMpdEntityId"
```

Then `flrp_reload_duty` (console) rebuilds the map with no restart. Any other
nex-duty entity (e.g. a `staff` dual-duty entity) is ignored for department pay.
`flrp_economy` is unchanged — it still calls `flrp_duty:GetDuty`.
