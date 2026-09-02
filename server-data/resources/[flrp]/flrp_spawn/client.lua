-- ==========================================================================
-- FLRP :: flrp_spawn/client.lua — spawn selector (open + debuggable)
-- ==========================================================================
-- Flow: on join, spawnmanager hands control to us instead of auto-spawning.
-- We put the player behind a map-overview camera + NUI, ask the server which
-- points this player may use (ace gating), and on selection spawn via
-- spawnmanager at the chosen coords. Everything here is plain, inspectable Lua.
-- ==========================================================================

local selecting = false
local cam = nil

local function setupCamera()
  cam = CreateCamWithParams(
    'DEFAULT_SCRIPTED_CAMERA',
    Config.Camera.pos.x, Config.Camera.pos.y, Config.Camera.pos.z,
    Config.Camera.rot.x, Config.Camera.rot.y, Config.Camera.rot.z,
    Config.Camera.fov, false, 0
  )
  SetCamActive(cam, true)
  RenderScriptCams(true, false, 0, true, true)
end

local function teardownCamera()
  RenderScriptCams(false, false, 0, true, true)
  if cam then
    DestroyCam(cam, false)
    cam = nil
  end
end

local function openSelector()
  if selecting then return end
  selecting = true

  local ped = PlayerPedId()
  SetEntityVisible(ped, false, false)
  FreezeEntityPosition(ped, true)
  SetPlayerControl(PlayerId(), false, 0)

  -- Make sure the connect loading screen is gone so the NUI is visible.
  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()

  DoScreenFadeIn(500)
  setupCamera()

  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', logo = Config.LogoUrl })
  -- Ask the server which gated points this player may use.
  TriggerServerEvent('flrp_spawn:requestPoints')
end

-- The server tells us which points are allowed; build the card list.
RegisterNetEvent('flrp_spawn:points', function(allowed)
  local list = {}
  for i, p in ipairs(Config.Points) do
    if allowed[i] then
      list[#list + 1] = { index = i, name = p.name, area = p.area or '', locked = p.ace ~= nil }
    end
  end
  SendNUIMessage({ action = 'points', points = list })
end)

-- Player clicked a card -> ask the server to approve it.
RegisterNUICallback('select', function(data, cb)
  local index = tonumber(data.index)
  if index then
    TriggerServerEvent('flrp_spawn:selectPoint', index)
  end
  cb('ok')
end)

RegisterNetEvent('flrp_spawn:denied', function()
  SendNUIMessage({ action = 'denied' })
end)

-- Approved: spawn there via spawnmanager and clean up.
RegisterNetEvent('flrp_spawn:approved', function(index)
  local p = Config.Points[index]
  if not p then return end

  DoScreenFadeOut(500)
  Wait(500)

  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  teardownCamera()

  exports.spawnmanager:spawnPlayer({
    x = p.coords.x, y = p.coords.y, z = p.coords.z, heading = p.coords.w,
    skipFade = true,
  }, function()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    SetGameplayCamRelativeHeading(0.0)
    ClearPedTasksImmediately(ped)
    Wait(300)
    DoScreenFadeIn(500)
    selecting = false
  end)
end)

-- Hand the spawn flow to us instead of letting spawnmanager auto-spawn.
AddEventHandler('onClientResourceStart', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  exports.spawnmanager:setAutoSpawnCallback(openSelector)
  exports.spawnmanager:setAutoSpawn(true)
  exports.spawnmanager:forceRespawn()
end)
