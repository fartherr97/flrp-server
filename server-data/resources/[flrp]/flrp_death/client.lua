-- ==========================================================================
-- FLRP :: flrp_death/client.lua — death timer, respawn, revive, dead-mute
-- ==========================================================================
-- On death we immediately resurrect the ped IN PLACE (cancels the game's
-- "wasted" auto-respawn and stops flrp_spawn's spawnmanager from opening the
-- selector), then hold the player in a downed state: ragdolled, invincible,
-- muted, no weapons. A red countdown shows centre-screen; at 0 the respawn key
-- teleports them to the nearest hospital. Staff skip the timer. Anyone can
-- /revive a nearby downed player, subject to the server's timer gate.
-- ==========================================================================

local C = FLRP_DEATH

local isDown     = false
local deathTime  = 0
local staffDeath = false
local deadCoords = nil
local deadHeading= 0.0

-- ---- draw helpers --------------------------------------------------------
local function text(str, x, y, scale, c, center)
  SetTextFont(4)
  SetTextScale(0.0, scale)
  SetTextColour(c[1], c[2], c[3], c[4] or 255)
  SetTextDropshadow(0, 0, 0, 0, 255)
  SetTextEdge(1, 0, 0, 0, 205)
  SetTextDropShadow()
  SetTextOutline()
  if center then SetTextCentre(true) end
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(str)
  EndTextCommandDisplayText(x, y)
end

local function toast(body, kind)
  TriggerEvent('flrp_notify:toast', { title = 'Medical', body = body, kind = kind or 'info' })
end

-- ---- state transitions ---------------------------------------------------
local function enterDowned()
  local ped = PlayerPedId()
  local c = GetEntityCoords(ped)
  deadCoords, deadHeading = c, GetEntityHeading(ped)
  isDown, deathTime, staffDeath = true, GetGameTimer(), false

  -- cancel the wasted screen: come back alive on the spot, then hold as "down"
  NetworkResurrectLocalPlayer(c.x, c.y, c.z, deadHeading, true, false)
  SetEntityHealth(ped, C.RespawnHealth)
  SetPlayerInvincible(PlayerId(), true)
  SetPedToRagdoll(ped, 60000, 60000, 0, false, false, false)
  NetworkSetVoiceActive(false)                       -- no voice while dead

  TriggerServerEvent('flrp_death:died')
end

local function clearDowned()
  local ped = PlayerPedId()
  isDown = false
  SetPlayerInvincible(PlayerId(), false)
  NetworkSetVoiceActive(true)
  ClearPedTasksImmediately(ped)
end

local function nearestHospital(coords)
  local best, bestD
  for _, h in ipairs(C.Hospitals) do
    local d = #(vector3(h.x, h.y, h.z) - coords)
    if not bestD or d < bestD then best, bestD = h, d end
  end
  return best
end

local function respawnAtHospital()
  local ped = PlayerPedId()
  local h = nearestHospital(deadCoords or GetEntityCoords(ped))
  clearDowned()
  NetworkResurrectLocalPlayer(h.x, h.y, h.z, h.w, true, false)
  SetEntityCoords(ped, h.x, h.y, h.z, false, false, false, true)
  SetEntityHeading(ped, h.w)
  SetEntityHealth(ped, C.RespawnHealth)
end

local function reviveInPlace()
  local ped = PlayerPedId()
  clearDowned()
  SetEntityHealth(ped, C.RespawnHealth)
end

local function secondsLeft()
  if staffDeath then return 0 end
  return math.max(0, C.WaitSeconds - math.floor((GetGameTimer() - deathTime) / 1000))
end

-- ---- death detection (baseevents fires promptly on any death) -------------
local function onDeath() if not isDown then enterDowned() end end
AddEventHandler('baseevents:onPlayerDied',   onDeath)
AddEventHandler('baseevents:onPlayerKilled', onDeath)
-- Fallback poll in case baseevents misses a cause.
CreateThread(function()
  while true do
    Wait(300)
    if not isDown and IsEntityDead(PlayerPedId()) then onDeath() end
  end
end)

-- ---- downed loop: hold state + draw UI -----------------------------------
local BLOCK = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 257, 263, 264, 22, 23, 21, 44 }
CreateThread(function()
  while true do
    if isDown then
      local ped = PlayerPedId()
      NetworkSetVoiceActive(false)
      for _, b in ipairs(BLOCK) do DisableControlAction(0, b, true) end
      if not IsPedRagdoll(ped) and not IsPedGettingUp(ped) then
        SetPedToRagdoll(ped, 30000, 30000, 0, false, false, false)
      end

      text(C.DeadText, 0.5, 0.045, 0.48, { 235, 235, 235, 220 }, true)
      local left = secondsLeft()
      if left > 0 then
        text(('%d'):format(left), 0.5, 0.40, 1.4, { 228, 42, 42, 255 }, true)
        text(C.LockedText, 0.5, 0.52, 0.5, { 228, 42, 42, 220 }, true)
      else
        text(C.RespawnText:format(C.RespawnKey), 0.5, 0.46, 0.7, { 236, 240, 244, 255 }, true)
      end
      Wait(0)
    else
      Wait(300)
    end
  end
end)

-- ---- respawn key ---------------------------------------------------------
RegisterCommand('flrp_respawn', function()
  if not isDown then return end
  if secondsLeft() > 0 then return end            -- still locked
  TriggerServerEvent('flrp_death:tryRespawn')
end, false)
RegisterKeyMapping('flrp_respawn', 'Respawn (when down)', 'keyboard', C.RespawnKey)

RegisterNetEvent('flrp_death:state', function(s)
  if type(s) == 'table' then staffDeath = s.staff and true or false end
end)
RegisterNetEvent('flrp_death:respawnApproved', function()
  if isDown then respawnAtHospital() end
end)
RegisterNetEvent('flrp_death:revived', function(bySrv)
  if isDown then reviveInPlace(); toast('You have been revived.', 'ok') end
end)

-- ---- revive (reviver side) -----------------------------------------------
local function nearestPlayerServerId()
  local me, myc = PlayerId(), GetEntityCoords(PlayerPedId())
  local best, bestD = nil, C.ReviveReach + 0.5
  for _, p in ipairs(GetActivePlayers()) do
    if p ~= me then
      local d = #(GetEntityCoords(GetPlayerPed(p)) - myc)
      if d < bestD then best, bestD = p, d end
    end
  end
  return best and GetPlayerServerId(best) or nil
end

local function doRevive()
  if isDown then return toast('You cannot revive while you are down.', 'error') end
  local t = nearestPlayerServerId()
  if not t then return toast('No one nearby to revive.', 'error') end
  TriggerServerEvent('flrp_death:revive', t)
end
RegisterCommand('revive', doRevive, false)
RegisterKeyMapping('revive', 'Medical: Revive nearest', 'keyboard', '')

-- Safety: if the resource stops while someone is down, clear their state.
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and isDown then clearDowned() end
end)
