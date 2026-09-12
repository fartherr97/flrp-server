-- ==========================================================================
-- FLRP :: flrp_spawn/client.lua — spawn selector (open + debuggable)
-- ==========================================================================
-- Flow: on join, spawnmanager hands control to us instead of auto-spawning.
-- We hide + freeze the player behind the (opaque, Miami-gradient) NUI with
-- the camera parked on empty sky, ask the server which points this player may
-- use (Discord-role gating), and on selection spawn via spawnmanager at the
-- chosen coords. Plain Lua throughout.
-- ==========================================================================

local selecting = false

-- While the selector is up the NUI is opaque, so aim the game camera at empty
-- sky far out over the ocean and move the streaming focus there: nothing to
-- render or stream behind the menu, which keeps the UI smooth on weaker PCs.
-- Cleared right before spawning so the destination streams in normally.
local IDLE_CAM = vector3(-3800.0, -4800.0, 600.0)
local idleCam  = nil

local function startIdleCam()
  SetFocusPosAndVel(IDLE_CAM.x, IDLE_CAM.y, IDLE_CAM.z, 0.0, 0.0, 0.0)
  idleCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  SetCamCoord(idleCam, IDLE_CAM.x, IDLE_CAM.y, IDLE_CAM.z)
  SetCamRot(idleCam, 25.0, 0.0, 180.0, 2)   -- tilted up: sky only
  SetCamActive(idleCam, true)
  RenderScriptCams(true, false, 0, true, true)
end

local function stopIdleCam()
  RenderScriptCams(false, false, 0, true, true)
  if idleCam then DestroyCam(idleCam, false); idleCam = nil end
  ClearFocus()
end

local function openSelector()
  if selecting then return end
  selecting = true

  local ped = PlayerPedId()
  -- If we opened because the player died, revive them where they fell first
  -- (they're hidden + frozen below) so the engine's wasted → hospital respawn
  -- doesn't race the selector. On a normal join the ped isn't dead → no-op.
  if IsEntityDead(ped) then
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ClearPedBloodDamage(ped)
    ped = PlayerPedId()
  end
  SetEntityVisible(ped, false, false)
  FreezeEntityPosition(ped, true)
  SetPlayerControl(PlayerId(), false, 0)

  -- Make sure the connect loading screen is gone so the NUI is visible.
  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()
  startIdleCam()
  DoScreenFadeIn(500)

  SetNuiFocus(true, true)
  SendNUIMessage({
    action     = 'open',
    logo       = Config.LogoUrl,
    header     = Config.Header,
    categories = Config.Categories,
    menu       = Config.Menu,
    playerName = GetPlayerName(PlayerId()),
  })
  -- Ask the server which gated points this player may use.
  TriggerServerEvent('flrp_spawn:requestPoints')
end

-- The server tells us which points are allowed; build the card list.
RegisterNetEvent('flrp_spawn:points', function(allowed, dynamic)
  local list = {}
  for i, p in ipairs(Config.Points) do
    local cat
    for _, c in ipairs(Config.Categories) do
      if c.id == (p.category or 'civ') then cat = c; break end
    end
    local gated = (p.roles and #p.roles > 0) or (cat and cat.roles and #cat.roles > 0) or false
    list[#list + 1] = {
      index      = i,
      name       = p.name,
      area       = p.area or '',
      desc       = p.desc or '',
      image      = p.image or nil,
      category   = p.category or 'civ',
      restricted = gated,                -- this point needs a role
      allowed    = allowed[i] == true,   -- whether THIS player may use it
    }
  end
  for _, p in ipairs(dynamic or {}) do list[#list+1] = p end
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

RegisterNetEvent('flrp_spawn:denied', function(reason)
  SendNUIMessage({ action = 'denied', reason = reason })
end)

-- Approved: spawn there via spawnmanager and clean up.
RegisterNetEvent('flrp_spawn:approved', function(index, coords)
  if not selecting then return end
  local p = (index == -1 or index == -2) and coords and {coords=coords} or Config.Points[index]
  if not p then return end

  DoScreenFadeOut(500)
  Wait(500)

  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  stopIdleCam()

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
    TriggerServerEvent('flrp_spawn:spawned')
  end)
end)

-- Hand the spawn flow to us instead of letting spawnmanager auto-spawn.
AddEventHandler('onClientResourceStart', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  exports.spawnmanager:setAutoSpawnCallback(openSelector)
  exports.spawnmanager:setAutoSpawn(true)
  exports.spawnmanager:forceRespawn()
end)

-- Respawn flow: when the player dies, reopen the selector instead of the
-- vanilla hospital respawn. openSelector() revives them in place first, so
-- picking a point cleanly moves them there.
CreateThread(function()
  while true do
    Wait(500)
    if Config.RespawnToSelector and not selecting and NetworkIsSessionStarted() then
      if IsEntityDead(PlayerPedId()) then
        local waited, delay = 0, (Config.RespawnDelay or 3000)
        while IsEntityDead(PlayerPedId()) and waited < delay do
          Wait(200); waited = waited + 200
        end
        if not selecting and IsEntityDead(PlayerPedId()) then
          openSelector()
        end
      end
    end
  end
end)

-- ---- Setup helper: /coords -----------------------------------------------
-- Stand where you want a spawn/jail/hospital point, face the direction players
-- should face, and run /coords. It prints a ready-to-paste vector4 to chat AND
-- the F8 console (select + copy there). Use it to fill Config.Points here, or
-- flrp_jail / flrp_death coord configs.
RegisterCommand('coords', function()
  local ped = PlayerPedId()
  local c = GetEntityCoords(ped)
  local line = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(ped))
  print('[flrp_spawn] ' .. line)
  TriggerEvent('chat:addMessage', { color = { 120, 220, 160 }, multiline = true, args = { 'COORDS', line } })
end, false)
TriggerEvent('chat:addSuggestion', '/coords', 'Print your current vector4(x, y, z, heading) — for wiring spawn / jail / hospital points')
