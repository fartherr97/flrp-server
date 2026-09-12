# Current AOP and Last Location

Quick Spawn adds two public choices without changing the Discord gates on
existing department spawn points.

Current AOP reads the server export `nex-hud:getAop().areas` when building the
menu and again when approving a selection. `Config.AopSpawns` maps area codes
to existing public spawn coordinates. Multiple active areas use the first
mapped area in Nex HUD's order; the card lists all active area labels.
Missing HUD data and unmapped-only AOPs disable the card with an explanation.
Fort Zancudo and custom zones require an explicit public destination to be
added to the mapping before they can be used.

Last Location is per license, stored with server resource KVPs. It survives
resource/server restarts and reconnects on the same server. The server records
its own ped coordinates every 15 seconds after an approved spawn completes,
plus disconnect/resource-stop saves where the ped remains available. Only
living on-foot players in routing bucket 0 are recorded. No client coordinate
payload is accepted. Opening the selector suspends sampling so the hidden or
revived preview ped never replaces the last gameplay position. Players without
a valid saved location see a disabled card; existing spawns remain available.
Positions from before this feature was installed cannot be reconstructed.

Validation: mocked Lua tests cover area changes at selection, multiple areas,
missing exports/unmapped codes, per-license isolation, save/reload behavior,
vehicle/death/bucket/selector exclusions, invalid coordinates, and existing
department role denial/approval. Vite production build passes. Actual return
spawns and map collision loading require an in-game check.

Deploy with a full server restart when empty: restarting flrp_spawn alone
forces connected players back through the selector.
