# pCore — proposed FLRP config (rebrand)

pCore (in the `flrp-scripts` repo) is a third-party, escrow-protected core that
currently ships **SSRP** configuration (old departments TPD/HCSO/HCFR, SSRP
Discord IDs, SSRP fleet, `discord.gg/ssrp`). FLRP builds on top of pCore
(see [`../../docs/PCORE_INTEGRATION.md`](../../docs/PCORE_INTEGRATION.md)), so
its config must be rebranded to FLRP.

**These files are a PROPOSAL for the pCore owner to review and build.** This
repo never edits pCore directly (it's their IP + escrow-protected). The owner
drops the reviewed files into `pCore/src/configs/`, runs `npm run build`, and
ships the new `dist/`.

## Files (mirror `pCore/src/configs/*`)

| File | Purpose | Status |
|------|---------|--------|
| `configs/discord.ts` | bot token + guild id | placeholders (set via env; never commit real token) |
| `configs/playerPerms.ts` | Discord role → FLRP group | **needs REAL Discord role IDs** (REPLACE_ME) |
| `configs/vehiclePerms.ts` | group → vehicle spawn names | seeded with **real imported** BCSO/FHP spawns; MPD empty |
| `configs/weaponPerms.ts` | group → weapons (vMenu spawn) | implements FLRP weapon policy |
| `configs/queue.ts` | queue + branding | FLRP branding; invite/website REPLACE_ME |

## Group names are load-bearing

pCore turns each group a player holds into an ACE principal
(`add_principal identifier.discord:<id> <groupKey>`). FLRP's bridge
(`config/permissions.cfg` + `flrp_permissions/server/pcore.lua`) maps those
exact group keys to `flrp.role.<key>`:

```
group.ownership → ownership   certciv1 → cert_civ_1   bcso → bcso
group.director  → director    certciv2 → cert_civ_2   fhp  → fhp
group.administrator → administrator  certciv3 → cert_civ_3   mpd → mpd
group.moderator → moderator   group.member → member
```

If you rename a group here, update the bridge (both files) to match.

## What still needs doing

1. Fill every `REPLACE_ME` Discord role ID in `playerPerms.ts` with the real
   FLRP guild role IDs (do **not** invent IDs).
2. Confirm the FLRP weapon list in `weaponPerms.ts` (only `certciv3` →
   director/ownership by inheritance may vMenu-spawn; everyone else buys at FLRP
   gun stores).
3. Add MPD vehicles once the MPD pack exists (`flrp-vehicles`).
4. Owner reviews, `npm run build`, ships. Then runtime-test that a player's
   FLRP roles resolve (console: check `IsPlayerAceAllowed` via FLRP logs).
