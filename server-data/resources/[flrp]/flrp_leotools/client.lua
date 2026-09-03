-- ==========================================================================
-- FLRP :: flrp_leotools/client.lua — cuff / drag / seat
-- ==========================================================================
-- Two roles in one file:
--   OFFICER: local `flrp_leotools:do*` events (from the flrp_interact LEO
--            Toolbox and /cuff /drag /seat commands) find the nearest target
--            and ask the server to apply the action.
--   TARGET:  server-sent `flrp_leotools:cuff/drag/seat/unseat` events apply the
--            actual restraint on this client's own ped.
-- ==========================================================================

local C = FLRP_LEO
local cuffed = false

local function toast(body, kind)
  TriggerEvent('flrp_notify:toast', { title = 'LEO', body = body, kind = kind or 'info' })
end

-- ---- OFFICER: target selection ------------------------------------------
local function nearestPlayerServerId()
  local me, myPed = PlayerId(), PlayerPedId()
  local myc = GetEntityCoords(myPed)
  local best, bestD = nil, C.Reach + 0.5
  for _, p in ipairs(GetActivePlayers()) do
    if p ~= me then
      local d = #(GetEntityCoords(GetPlayerPed(p)) - myc)
      if d < bestD then best, bestD = p, d end
    end
  end
  return best and GetPlayerServerId(best) or nil
end

-- Nearest vehicle to the officer + first free rear seat -> (netId, seat) or nil.
local function nearestVehicleSeat()
  local ped = PlayerPedId()
  local c = GetEntityCoords(ped)
  local veh = GetClosestVehicle(c.x, c.y, c.z, C.SeatReach, 0, 71)
  if not veh or veh == 0 then return nil end
  local seat
  if IsVehicleSeatFree(veh, 1) then seat = 1
  elseif IsVehicleSeatFree(veh, 2) then seat = 2
  elseif IsVehicleSeatFree(veh, 0) then seat = 0 end
  if not seat then return nil end
  if not NetworkGetEntityIsNetworked(veh) then NetworkRegisterEntityAsNetworked(veh) end
  NetworkRequestControlOfEntity(veh)
  return NetworkGetNetworkIdFromEntity(veh), seat
end

local function doCuff()
  local t = nearestPlayerServerId()
  if not t then return toast('No one within reach.', 'error') end
  TriggerServerEvent('flrp_leotools:cuff', t)
end
local function doDrag()
  local t = nearestPlayerServerId()
  if not t then return toast('No one within reach.', 'error') end
  TriggerServerEvent('flrp_leotools:drag', t)
end
local function doSeat()
  local t = nearestPlayerServerId()
  if not t then return toast('No one within reach.', 'error') end
  local netId, seat = nearestVehicleSeat()
  if not netId then return toast('No vehicle with a free seat nearby.', 'error') end
  TriggerServerEvent('flrp_leotools:seat', t, netId, seat)
end
local function doUnseat()
  local t = nearestPlayerServerId()
  if not t then return toast('No one within reach.', 'error') end
  TriggerServerEvent('flrp_leotools:unseat', t)
end

-- flrp_interact LEO Toolbox hooks (client_event actions)
AddEventHandler('flrp_leotools:doCuff',   doCuff)
AddEventHandler('flrp_leotools:doDrag',   doDrag)
AddEventHandler('flrp_leotools:doSeat',   doSeat)
AddEventHandler('flrp_leotools:doUnseat', doUnseat)

-- Commands (server re-checks the ACE)
RegisterCommand('cuff',   doCuff,   false)
RegisterCommand('drag',   doDrag,   false)
RegisterCommand('seat',   doSeat,   false)
RegisterCommand('unseat', doUnseat, false)

-- ---- TARGET: apply restraint --------------------------------------------
local function loadAnimDict(dict)
  RequestAnimDict(dict)
  local t = GetGameTimer()
  while not HasAnimDictLoaded(dict) and (GetGameTimer() - t) < 3000 do Wait(10) end
  return HasAnimDictLoaded(dict)
end

local function playCuffAnim()
  local ped = PlayerPedId()
  if loadAnimDict(C.Cuff.animDict) then
    TaskPlayAnim(ped, C.Cuff.animDict, C.Cuff.anim, 8.0, -8.0, -1, 49, 0.0, false, false, false)
  end
  RequestAnimSet(C.Cuff.clipset)
  local t = GetGameTimer()
  while not HasAnimSetLoaded(C.Cuff.clipset) and (GetGameTimer() - t) < 3000 do Wait(10) end
  if HasAnimSetLoaded(C.Cuff.clipset) then SetPedMovementClipset(ped, C.Cuff.clipset, 1.0) end
end

-- While cuffed: block weapons/attacks and keep the pose sticky.
CreateThread(function()
  while true do
    if cuffed then
      local ped = PlayerPedId()
      DisablePlayerFiring(PlayerId(), true)
      DisableControlAction(0, 24, true)  DisableControlAction(0, 25, true)   -- attack / aim
      DisableControlAction(0, 37, true)                                       -- weapon wheel
      DisableControlAction(0, 140, true) DisableControlAction(0, 141, true)   -- melee
      DisableControlAction(0, 142, true) DisableControlAction(0, 257, true)
      DisableControlAction(0, 263, true) DisableControlAction(0, 264, true)
      DisableControlAction(0, 47, true)  DisableControlAction(0, 58, true)    -- weapon / grenade
      if not IsEntityAttachedToAnyPed(ped)
         and not IsPedInAnyVehicle(ped, false)
         and not IsEntityPlayingAnim(ped, C.Cuff.animDict, C.Cuff.anim, 3) then
        playCuffAnim()
      end
      Wait(0)
    else
      Wait(300)
    end
  end
end)

RegisterNetEvent('flrp_leotools:cuff', function(_officer, on)
  cuffed = on and true or false
  local ped = PlayerPedId()
  if cuffed then
    playCuffAnim()
  else
    ClearPedTasks(ped)
    ResetPedMovementClipset(ped, 0.0)
  end
end)

RegisterNetEvent('flrp_leotools:drag', function(officerSrv, on)
  local ped = PlayerPedId()
  if on and officerSrv then
    local op = GetPlayerPed(GetPlayerFromServerId(officerSrv))
    if op and op ~= 0 then
      AttachEntityToEntity(ped, op, C.Drag.bone, C.Drag.x, C.Drag.y, C.Drag.z,
        C.Drag.rx, C.Drag.ry, C.Drag.rz, false, false, false, false, 2, true)
    end
  else
    if IsEntityAttachedToAnyEntity(ped) then DetachEntity(ped, true, false) end
  end
end)

RegisterNetEvent('flrp_leotools:seat', function(vehNet, seat)
  local ped = PlayerPedId()
  if IsEntityAttachedToAnyEntity(ped) then DetachEntity(ped, true, false) end
  local t = GetGameTimer()
  local veh = NetworkGetEntityFromNetworkId(vehNet)
  while (not veh or veh == 0 or not DoesEntityExist(veh)) and (GetGameTimer() - t) < 2000 do
    Wait(20); veh = NetworkGetEntityFromNetworkId(vehNet)
  end
  if veh and veh ~= 0 and DoesEntityExist(veh) then
    NetworkRequestControlOfEntity(veh)
    TaskWarpPedIntoVehicle(ped, veh, seat or 1)
  end
end)

RegisterNetEvent('flrp_leotools:unseat', function()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh and veh ~= 0 then TaskLeaveVehicle(ped, veh, 0) end
end)

-- Safety: on resource stop, clear our own restraint so we're never stuck.
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  local ped = PlayerPedId()
  if IsEntityAttachedToAnyEntity(ped) then DetachEntity(ped, true, false) end
  ClearPedTasks(ped)
  ResetPedMovementClipset(ped, 0.0)
end)
