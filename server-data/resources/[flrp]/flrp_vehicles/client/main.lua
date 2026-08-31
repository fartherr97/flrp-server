-- ==========================================================================
-- FLRP :: flrp_vehicles/client/main.lua — spawn gate helper
-- ==========================================================================
-- Provides a client helper that asks the server whether a registry vehicle may
-- be spawned, and only spawns on an authoritative "allow". This is the FLRP
-- integration point for a spawn menu / vMenu hook. The server decision is
-- authoritative; this client merely honours it. See docs/VEHICLES.md.
-- ==========================================================================

local pending = {} -- spawnName -> true (awaiting decision)

-- Public export other client scripts / menus can call.
-- exports.flrp_vehicles:TrySpawn(spawnName)
local function trySpawn(spawnName)
  if not spawnName or spawnName == '' then return end
  pending[string.lower(spawnName)] = true
  TriggerServerEvent('flrp_vehicles:requestSpawn', spawnName)
end
exports('TrySpawn', trySpawn)

RegisterNetEvent('flrp_vehicles:spawnDecision', function(spawnName, ok, reason)
  local key = string.lower(spawnName or '')
  if not pending[key] then return end
  pending[key] = nil
  if not ok then
    -- Denied by server; surface a hint and do NOT spawn.
    TriggerEvent('chat:addMessage', {
      color = { 200, 60, 60 },
      args = { 'FLRP Vehicles', ('You are not permitted to spawn %s (%s)'):format(spawnName, reason or 'denied') },
    })
    return
  end
  spawnAuthorizedVehicle(spawnName)
end)

function spawnAuthorizedVehicle(spawnName)
  local hash = GetHashKey(spawnName)
  if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return end
  RequestModel(hash)
  local t = GetGameTimer()
  while not HasModelLoaded(hash) and (GetGameTimer() - t) < 5000 do Wait(10) end
  if not HasModelLoaded(hash) then return end
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
  SetPedIntoVehicle(ped, veh, -1)
  SetModelAsNoLongerNeeded(hash)
  SetVehicleNumberPlateText(veh, 'FLRP')
end
