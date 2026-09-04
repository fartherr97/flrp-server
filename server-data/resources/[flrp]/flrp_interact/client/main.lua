-- ==========================================================================
-- FLRP :: flrp_interact/client/main.lua — keybind, menu tree, actions
-- ==========================================================================
-- Press M -> ask the server for a per-player manifest (which categories the
-- player may see + their spawnable donator vehicles), build the native menu
-- from config + manifest, and dispatch selections.
-- ==========================================================================

local building = false

-- ---- server manifest (req/res) -------------------------------------------
local pending, seq = {}, 0
local function request(action, payload, cb)
  seq = seq + 1
  pending[seq] = cb
  TriggerServerEvent('flrp_interact:req', action, payload or {}, seq)
end
RegisterNetEvent('flrp_interact:res', function(id, data)
  local cb = pending[id]; pending[id] = nil
  if cb then cb(data) end
end)

-- ---- built-in emotes -----------------------------------------------------
local Emotes = {
  handsup   = { dict = 'missminuteman_1ig_2', anim = 'handsup_base', flag = 49 },
  surrender = { scenario = 'CODE_HUMAN_MEDIC_TEND_TO_DEAD' }, -- kneel-over pose
  sit       = { scenario = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER' },
}

local function playEmote(key)
  local e = Emotes[key]; if not e then return end
  local ped = PlayerPedId()
  ClearPedTasks(ped)
  if e.scenario then
    TaskStartScenarioInPlace(ped, e.scenario, 0, true)
    return
  end
  RequestAnimDict(e.dict)
  local t = GetGameTimer()
  while not HasAnimDictLoaded(e.dict) and (GetGameTimer() - t) < 3000 do Wait(10) end
  if HasAnimDictLoaded(e.dict) then
    TaskPlayAnim(ped, e.dict, e.anim, 8.0, -8.0, -1, e.flag or 49, 0.0, false, false, false)
  end
end

local function toast(body, kind)
  TriggerEvent('flrp_notify:toast', { title = 'FLRP', body = body, kind = kind or 'info' })
end

-- Native on-screen keyboard -> string or nil.
local function keyboard(title, maxLen)
  AddTextEntry('FLRP_INTERACT_KB', title)
  DisplayOnscreenKeyboard(1, 'FLRP_INTERACT_KB', '', '', '', '', '', maxLen or 180)
  while UpdateOnscreenKeyboard() == 0 do Wait(0) end
  if GetOnscreenKeyboardResult() then
    return tostring(GetOnscreenKeyboardResult())
  end
  return nil
end

-- ---- action dispatch (toolbox items) -------------------------------------
local function runAction(it)
  local a, arg = it.action, it.arg
  if a == 'emote' then playEmote(arg)
  elseif a == 'scenario' then
    local ped = PlayerPedId(); ClearPedTasks(ped); TaskStartScenarioInPlace(ped, arg, 0, true)
  elseif a == 'cancel' then ClearPedTasks(PlayerPedId())
  elseif a == 'command' then ExecuteCommand(arg)
  elseif a == 'client_event' then TriggerEvent(arg)
  elseif a == 'server_event' then TriggerServerEvent(arg)
  end
end

-- ---- vehicle controls ----------------------------------------------------
-- The vehicle the player is in, or the closest one within 5m.
local function targetVehicle()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh and veh ~= 0 then return veh end
  local c = GetEntityCoords(ped)
  veh = GetClosestVehicle(c.x, c.y, c.z, 5.0, 0, 71)
  if veh and veh ~= 0 then return veh end
  return nil
end

local function withVehicle(fn)
  local veh = targetVehicle()
  if not veh then return toast('No vehicle nearby.', 'error') end
  if NetworkGetEntityIsNetworked(veh) then NetworkRequestControlOfEntity(veh) end
  fn(veh)
end

local DOORS = { { 'Front Left', 0 }, { 'Front Right', 1 }, { 'Rear Left', 2 }, { 'Rear Right', 3 } }
local hazardsOn = false

local function vehicleControlsMenu()
  local m = FLRPMenu.New(FLRP_INTERACT.Title, 'VEHICLE CONTROLS')

  m:Item({ label = 'Engine', desc = 'Toggle the engine on or off.', onSelect = function()
    withVehicle(function(v) SetVehicleEngineOn(v, not GetIsVehicleEngineRunning(v), false, true) end)
  end })
  m:Item({ label = 'Doors Lock', desc = 'Lock or unlock the vehicle.', onSelect = function()
    withVehicle(function(v)
      local locked = GetVehicleDoorLockStatus(v) == 2
      SetVehicleDoorsLocked(v, locked and 1 or 2)
      toast(locked and 'Doors unlocked.' or 'Doors locked.', 'ok')
    end)
  end })

  -- Doors submenu (open/close each)
  local doors = FLRPMenu.New(FLRP_INTERACT.Title, 'DOORS')
  for _, d in ipairs(DOORS) do
    doors:Item({ label = d[1], desc = 'Open or close this door.', onSelect = function()
      withVehicle(function(v)
        if GetVehicleDoorAngleRatio(v, d[2]) > 0.1 then SetVehicleDoorShut(v, d[2], false)
        else SetVehicleDoorOpen(v, d[2], false, false) end
      end)
    end })
  end
  doors:Item({ label = 'Hood', desc = 'Open or close the hood.', onSelect = function()
    withVehicle(function(v) if GetVehicleDoorAngleRatio(v, 4) > 0.1 then SetVehicleDoorShut(v, 4, false) else SetVehicleDoorOpen(v, 4, false, false) end end)
  end })
  doors:Item({ label = 'Trunk', desc = 'Open or close the trunk.', onSelect = function()
    withVehicle(function(v) if GetVehicleDoorAngleRatio(v, 5) > 0.1 then SetVehicleDoorShut(v, 5, false) else SetVehicleDoorOpen(v, 5, false, false) end end)
  end })
  m:Item({ label = 'Doors', right = '›', desc = 'Open or close individual doors.', sub = doors })

  -- Windows submenu
  local windows = FLRPMenu.New(FLRP_INTERACT.Title, 'WINDOWS')
  for _, d in ipairs(DOORS) do
    windows:Item({ label = d[1], desc = 'Roll this window up or down.', onSelect = function()
      withVehicle(function(v)
        if IsVehicleWindowIntact(v, d[2]) then RollDownWindow(v, d[2]) else RollUpWindow(v, d[2]) end
      end)
    end })
  end
  m:Item({ label = 'Windows', right = '›', desc = 'Roll windows up or down.', sub = windows })

  m:Item({ label = 'Headlights', desc = 'Toggle the headlights.', onSelect = function()
    withVehicle(function(v)
      local _, lightsOn = GetVehicleLightsState(v)
      SetVehicleLights(v, lightsOn == 1 and 1 or 2) -- 1 = force off, 2 = force on
    end)
  end })
  m:Item({ label = 'Hazards', desc = 'Toggle the hazard lights.', onSelect = function()
    withVehicle(function(v)
      hazardsOn = not hazardsOn
      SetVehicleIndicatorLights(v, 0, hazardsOn); SetVehicleIndicatorLights(v, 1, hazardsOn)
      toast(hazardsOn and 'Hazards on.' or 'Hazards off.', 'ok')
    end)
  end })

  return m
end

-- ---- advert flow ---------------------------------------------------------
local function doAdvert(kind)  -- 'civ' | 'leo'
  FLRPMenu.Close()
  Wait(50)
  local title = (kind == 'leo') and 'Department advisory' or 'Advertisement text'
  local msg = keyboard(title, FLRP_INTERACT.Ads.MaxLength)
  if not msg or msg:gsub('%s', '') == '' then return end
  request(kind == 'leo' and 'leoAd' or 'civAd', { text = msg }, function(r)
    if not r then return end
    if r.ok then toast(r.msg or 'Advertisement sent.', 'ok')
    else toast(r.error or 'Could not send.', 'error') end
  end)
end

-- ---- menu tree -----------------------------------------------------------
local function toolboxMenu(title, items)
  local m = FLRPMenu.New(FLRP_INTERACT.Title, title)
  for _, it in ipairs(items) do
    m:Item({
      label = it.label, desc = it.desc,
      onSelect = function() runAction(it); FLRPMenu.Close() end,
    })
  end
  if #items == 0 then m:Item({ label = 'Nothing here yet', disabled = true }) end
  return m
end

local function vehicleMenu(vehicles)
  local m = FLRPMenu.New(FLRP_INTERACT.Title, 'DONATOR VEHICLES')
  if not vehicles or #vehicles == 0 then
    m:Item({ label = 'No vehicles available', desc = 'Spawn access is granted per vehicle.', disabled = true })
    return m
  end
  for _, v in ipairs(vehicles) do
    m:Item({
      label = v.displayName or v.spawnName,
      right = v.department or nil,
      desc  = ('Spawn %s.'):format(v.displayName or v.spawnName),
      onSelect = function()
        FLRPMenu.Close()
        exports.flrp_vehicles:TrySpawn(v.spawnName)
      end,
    })
  end
  return m
end

-- ---- stations (LEO teleports) --------------------------------------------
local function teleportTo(x, y, z, h)
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
    SetEntityCoords(veh, x, y, z, false, false, false, false); SetEntityHeading(veh, h or 0.0)
  else
    SetEntityCoords(ped, x, y, z, false, false, false, false); SetEntityHeading(ped, h or 0.0)
  end
end

local function stationsMenu()
  local m = FLRPMenu.New(FLRP_INTERACT.Title, 'STATIONS')
  local list = FLRP_INTERACT.Stations or {}
  if #list == 0 then
    m:Item({ label = 'No stations set', desc = 'Add stations in flrp_interact/config.lua.', disabled = true })
    return m
  end
  for _, s in ipairs(list) do
    m:Item({ label = s.label, desc = 'Teleport to ' .. (s.label or 'station') .. '.', onSelect = function()
      FLRPMenu.Close()
      teleportTo(s.x + 0.0, s.y + 0.0, s.z + 0.0, s.h or 0.0)
      toast('Teleported to ' .. (s.label or 'station') .. '.', 'ok')
    end })
  end
  return m
end

local function build(manifest)
  local root = FLRPMenu.New(FLRP_INTERACT.Title, FLRP_INTERACT.Subtitle)

  -- Civilian toolbox (everyone)
  root:Item({ label = 'Civilian Toolbox', right = '›', desc = 'Emotes and civilian actions.',
              sub = toolboxMenu('CIVILIAN TOOLBOX', FLRP_INTERACT.CivilianToolbox) })

  -- LEO toolbox (flrp.leo)
  if manifest.leo then
    root:Item({ label = 'LEO Toolbox', right = '›', desc = 'Law-enforcement tools.',
                sub = toolboxMenu('LEO TOOLBOX', FLRP_INTERACT.LeoToolbox) })
    root:Item({ label = 'Stations', right = '›', desc = 'Teleport to stations and set areas.',
                sub = stationsMenu() })
  end

  -- Vehicle controls (everyone) — engine, locks, doors, windows, lights
  root:Item({ label = 'Vehicle Controls', right = '›', desc = 'Engine, locks, doors, windows, lights.',
              sub = vehicleControlsMenu() })

  -- Donator vehicle spawns
  if manifest.donator then
    root:Item({ label = 'Donator Vehicles', right = '›', desc = 'Spawn your donator vehicles.',
                sub = vehicleMenu(manifest.vehicles) })
  end

  -- Civilian advertisement (everyone)
  root:Item({ label = 'Civilian Advertisement', desc = 'Broadcast a business advert to the server.',
              onSelect = function() doAdvert('civ') end })

  -- LEO department advisory (flrp.leo)
  if manifest.leo then
    root:Item({ label = 'Department Advisory', desc = 'Broadcast a department advisory to the server.',
                onSelect = function() doAdvert('leo') end })
  end

  root:Item({ label = 'Close', desc = 'Close the menu.', close = true })
  return root
end

-- ---- keybind -------------------------------------------------------------
local function openMenu()
  if FLRPMenu.IsOpen() then return FLRPMenu.Close() end
  if building then return end
  if IsPauseMenuActive() then return end
  building = true
  -- Never let a missed server reply jam the menu shut forever.
  SetTimeout(3000, function() building = false end)
  request('open', {}, function(manifest)
    building = false
    if type(manifest) ~= 'table' then return end
    FLRPMenu.Open(build(manifest))
  end)
end

-- Command + rebindable keymapping (appears in Settings > Key Bindings > FiveM).
RegisterCommand('flrp_interact_toggle', function() openMenu() end, false)
RegisterCommand('interact', function() openMenu() end, false)          -- friendly alias
RegisterKeyMapping('flrp_interact_toggle', 'FLRP: Interaction menu', 'keyboard', FLRP_INTERACT.Key)

-- Primary open path: poll the raw M control (INPUT_INTERACTION_MENU = 244)
-- directly, like vMenu does. This works even if the keymapping default didn't
-- bind because M was already claimed in a player's keybinds (vMenu moved to F1,
-- so 244 is free). Rebindable keymapping above still works alongside it.
CreateThread(function()
  while true do
    Wait(0)
    if not IsPauseMenuActive() and IsControlJustPressed(0, 244) then
      openMenu()  -- toggles: opens when closed, closes when open
    end
  end
end)

-- Close on resource stop so we never leave the draw loop / controls locked.
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and FLRPMenu.IsOpen() then FLRPMenu.Close() end
end)
