-- ==========================================================================
-- FLRP :: flrp_spawn/client.lua — spawn selector (open + debuggable)
-- ==========================================================================
-- Flow: on join, spawnmanager hands control to us instead of auto-spawning.
-- We put the player behind a map-overview camera + NUI, ask the server which
-- points this player may use (ace gating), and on selection spawn via
-- spawnmanager at the chosen coords. Everything here is plain, inspectable Lua.
-- ==========================================================================

local selecting   = false
local activeCam   = nil
local focusedIdx  = nil    -- which point the preview camera is showing
local camGen      = 0      -- guards against out-of-order interp cleanups

-- Build a scenic preview camera for a point: sit behind + above the spawn,
-- looking at it. `preview` (per-point) or Config.Preview tunes dist/height/fov.
local function makePreviewCam(p)
  local pv = p.preview or Config.Preview
  local c  = p.coords
  local rad = math.rad(c.w)
  local fx, fy = -math.sin(rad), math.cos(rad)   -- forward vector from heading
  local camx = c.x - fx * pv.dist
  local camy = c.y - fy * pv.dist
  local camz = c.z + pv.height

  local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  SetCamCoord(cam, camx, camy, camz)
  PointCamAtCoord(cam, c.x, c.y, c.z + 1.0)
  SetCamFov(cam, pv.fov)
  return cam
end

-- Fly the preview camera to a point and stream that area so the REAL location
-- renders behind the (translucent) cards.
local function focusPoint(index)
  local p = Config.Points[index]
  if not p or index == focusedIdx then return end
  focusedIdx = index

  -- Force the engine to stream world/collision around the previewed spot,
  -- otherwise a far location shows as empty LOD.
  SetFocusPosAndVel(p.coords.x, p.coords.y, p.coords.z, 0.0, 0.0, 0.0)

  local newCam = makePreviewCam(p)
  if activeCam then
    SetCamActiveWithInterp(newCam, activeCam, Config.Preview.interp, 1, 1)
    RenderScriptCams(true, false, 0, true, true)
    local old = activeCam
    activeCam = newCam
    camGen = camGen + 1
    local myGen = camGen
    SetTimeout(Config.Preview.interp + 120, function()
      if old and old ~= activeCam and myGen == camGen then DestroyCam(old, false) end
    end)
  else
    activeCam = newCam
    SetCamActive(newCam, true)
    RenderScriptCams(true, false, 0, true, true)
  end
end

local function teardownCamera()
  RenderScriptCams(false, false, 0, true, true)
  if activeCam then DestroyCam(activeCam, false); activeCam = nil end
  ClearFocus()
  focusedIdx = nil
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
  -- Open on the first point; the NUI drives the camera from there as the
  -- player moves between cards (see the 'focus' callback below).
  focusPoint(1)

  SetNuiFocus(true, true)
  SendNUIMessage({
    action     = 'open',
    logo       = Config.LogoUrl,
    header     = Config.Header,
    playerName = GetPlayerName(PlayerId()),
  })
  -- Ask the server which gated points this player may use.
  TriggerServerEvent('flrp_spawn:requestPoints')
end

-- The server tells us which points are allowed; build the card list.
RegisterNetEvent('flrp_spawn:points', function(allowed)
  local list = {}
  for i, p in ipairs(Config.Points) do
    if allowed[i] then
      list[#list + 1] = {
        index  = i,
        name   = p.name,
        area   = p.area or '',
        desc   = p.desc or '',
        image  = p.image or nil,
        locked = p.ace ~= nil,
      }
    end
  end
  SendNUIMessage({ action = 'points', points = list })
end)

-- Player focused a card (hover / scroll) -> fly the preview camera there.
RegisterNUICallback('focus', function(data, cb)
  local index = tonumber(data.index)
  if index then focusPoint(index) end
  cb('ok')
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
