-- ==========================================================================
-- FLRP :: flrp_vehicles/server/main.lua — boot + spawn validation
-- ==========================================================================

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRPV.Registry.Load()
  FLRP.Logger.Info('vehicles', 'flrp_vehicles ready', {
    enforce = FLRP.Util.ConvarBool('flrp_vehicles_enforce_permissions', true) })
end)

-- Authoritative spawn check requested by the client BEFORE it spawns a
-- registry vehicle. The client must honour a deny; additionally, integrations
-- (e.g. a vMenu hook or a spawn menu) should call this server-side. Because a
-- rogue client could ignore the deny, this is the authoritative gate that any
-- server-side spawn path must consult — see docs/VEHICLES.md for wiring vMenu.
RegisterNetEvent('flrp_vehicles:requestSpawn', function(spawnName)
  local source = tonumber(source)
  local ok, reason = FLRPV.Registry.CanSpawn(source, spawnName)
  if not ok then
    FLRP.Logger.Debug('vehicles', 'Spawn denied', { source = source, spawnName = spawnName, reason = reason })
  end
  TriggerClientEvent('flrp_vehicles:spawnDecision', source, spawnName, ok, reason)
end)

RegisterCommand('flrp_reload_vehicles', function(source)
  if source ~= 0 and not (exports.flrp_permissions and exports.flrp_permissions:HasPermission(source, 'vehicles.manage')) then
    return
  end
  FLRPV.Registry.Load()
  FLRP.Logger.Info('vehicles', 'Vehicle registry reloaded')
end, false)
