# FLRP Departments

The authoritative FLRP law-enforcement departments are:

- **BCSO** — Bay County Sheriff's Office
- **FHP** — Florida Highway Patrol
- **MPD** — Municipal Police Department

> Legacy names (HCSO, TPD, etc.) are **not** used anywhere in this build.

## How departments are modeled

A department is a **role** (`roles.key` = `bcso` / `fhp` / `mpd`, `kind =
department`). Membership comes from the corresponding Discord role
(`flrp_role_bcso` / `flrp_role_fhp` / `flrp_role_mpd`, or a DB mapping). Holding
the role means the player *may* work that department; it does not by itself put
them on duty.

## Duty (server-authoritative)

`flrp_duty` tracks one current duty state per player: a department + on/off. It
is **server-authoritative** — a duty change is only honoured if the player
actually holds that department's role (verified via `flrp_permissions`). A
client cannot spoof itself onto a department.

```lua
exports.flrp_duty:GetDuty(source)            -- { department = 'BCSO'|nil, onDuty = bool }
exports.flrp_duty:IsOnDuty(source, 'FHP')    -- bool
exports.flrp_duty:SetDuty(source, 'MPD', true)   -- validated; ok, err
exports.flrp_duty:GoOffDuty(source)
```

In-game: `/duty <bcso|fhp|mpd>` to go on duty for a department you belong to, and
`/duty off` (or `/duty civ`) to go civilian. There is also a validated net event
`flrp_duty:request(department, onDuty)` for a future NUI. State is persisted
(`player_duty_state`) and every transition is logged (`player_duty_log`) and
audited.

On load, if a player was persisted on-duty but no longer holds the department
role (roles changed between sessions), they are forced off duty.

## Department pay

Department pay only applies **while actually on duty** in that department:

```
Has FHP role  +  chose FHP duty  +  active  =  FHP pay
Same player goes civilian        =  civilian/certification pay
```

`flrp_economy` asks `flrp_duty` for the current duty each pay cycle and pays the
department rate when on duty, otherwise the best civilian/cert rate. See
[ECONOMY.md](ECONOMY.md).

## Department resources

`[departments]/[bcso]`, `[fhp]`, `[mpd]` hold department-specific glue
(loadouts, vehicle registration hooks, blips/zones). They are minimal for now —
most behavior is centralized in the `[flrp]` services. Add a `fxmanifest.lua` +
`ensure flrp_<dept>` only when a department needs its own runtime code.

## Ranks (future)

`vehicles.min_rank` and the supervisor/command vehicle permission tiers exist in
the schema for a future department rank system. Until ranks are implemented,
grant supervisor/command permissions explicitly (via the FLRP Manager) or leave
them ungranted.
