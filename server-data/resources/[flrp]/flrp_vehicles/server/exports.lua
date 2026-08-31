-- ==========================================================================
-- FLRP :: flrp_vehicles/server/exports.lua — public API
-- ==========================================================================
--   exports.flrp_vehicles:GetVehicle(spawnName)        -> vehicle|nil
--   exports.flrp_vehicles:CanSpawn(source, spawnName)  -> ok, reason (authoritative)
--   exports.flrp_vehicles:ListForPlayer(source)        -> [{...}]
--   exports.flrp_vehicles:RegisterVehicle(vehicleTbl)  -> ok  (import/Manager)
--   exports.flrp_vehicles:ReloadRegistry()             -> bool
-- ==========================================================================

function GetVehicle(spawnName) return FLRPV.Registry.Get(spawnName) end
function CanSpawn(source, spawnName) return FLRPV.Registry.CanSpawn(source, spawnName) end
function ListForPlayer(source) return FLRPV.Registry.ListForPlayer(source) end
function RegisterVehicle(v) return FLRPV.Registry.Register(v) end
function ReloadRegistry() return FLRPV.Registry.Load() end
