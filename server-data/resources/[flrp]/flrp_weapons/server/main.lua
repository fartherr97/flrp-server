-- ==========================================================================
-- FLRP :: flrp_weapons/server/main.lua — boot + wiring
-- ==========================================================================

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRPW.Registry.Load()
  FLRP.Logger.Info('weapons', 'flrp_weapons ready')
end)

AddEventHandler('flrp_core:playerLoaded', function(source, playerId, record)
  local owned = FLRPW.Ownership.Load(source, playerId)
  local list = {}
  for name in pairs(owned) do list[#list + 1] = name end
  -- Tell the client which weapons to (re)apply on spawn.
  TriggerClientEvent('flrp_weapons:setOwned', source, list)
end)

AddEventHandler('flrp_core:playerDropped', function(source)
  FLRPW.Ownership.Remove(source)
end)

-- Client may request its owned list (e.g. after a fresh spawn).
RegisterNetEvent('flrp_weapons:requestOwned', function()
  local source = tonumber(source)
  TriggerClientEvent('flrp_weapons:setOwned', source, FLRPW.Ownership.List(source))
end)

RegisterCommand('flrp_reload_weapons', function(source)
  if source ~= 0 and not (exports.flrp_permissions and exports.flrp_permissions:HasPermission(source, 'weapons.manage')) then
    return
  end
  FLRPW.Registry.Load()
  FLRP.Logger.Info('weapons', 'Weapon registry reloaded')
end, false)
