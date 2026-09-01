# FLRP Third-Party Scripts (flrp-scripts) — keep / remove

Decisions for the escrowed resources in the `flrp-scripts` content repo. See
[ASSET_INVENTORY.md](ASSET_INVENTORY.md).

| Resource | Decision | Notes |
|----------|----------|-------|
| **pCore** | **KEEP (core)** | Identity / Discord gate / queue / permissions / vMenu. FLRP builds on it — [PCORE_INTEGRATION.md](PCORE_INTEGRATION.md). |
| **nex-duty** | **KEEP (duty authority)** | Replaces `flrp_duty`'s own duty state. `flrp_duty` becomes a thin adapter (below). |
| nex-hud | **REMOVE** | Not `ensure`d; delete from flrp-scripts. |
| nex-loading | **REMOVE** | Not `ensure`d; delete from flrp-scripts. |
| nex-spawn | **REMOVE** | Not `ensure`d; delete from flrp-scripts. |
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

Needs from you: the nex-duty **entity IDs** you configure for BCSO / FHP / MPD
(e.g. `bcso`, `fhp`, `mpd`, or whatever you name them in nex-duty's config), so
the adapter can map entity → FLRP department. Then I build the adapter.
