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
  elseif a == 'cancel' then ClearPedTasks(PlayerPedId())
  elseif a == 'command' then ExecuteCommand(arg)
  elseif a == 'client_event' then TriggerEvent(arg)
  elseif a == 'server_event' then TriggerServerEvent(arg)
  end
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

local function build(manifest)
  local root = FLRPMenu.New(FLRP_INTERACT.Title, FLRP_INTERACT.Subtitle)

  -- Civilian toolbox (everyone)
  root:Item({ label = 'Civilian Toolbox', right = '›', desc = 'Emotes and civilian actions.',
              sub = toolboxMenu('CIVILIAN TOOLBOX', FLRP_INTERACT.CivilianToolbox) })

  -- LEO toolbox (flrp.leo)
  if manifest.leo then
    root:Item({ label = 'LEO Toolbox', right = '›', desc = 'Law-enforcement tools.',
                sub = toolboxMenu('LEO TOOLBOX', FLRP_INTERACT.LeoToolbox) })
  end

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
  request('open', {}, function(manifest)
    building = false
    if type(manifest) ~= 'table' then return end
    FLRPMenu.Open(build(manifest))
  end)
end

RegisterCommand('flrp_interact_toggle', function() openMenu() end, false)
RegisterKeyMapping('flrp_interact_toggle', 'FLRP: Interaction menu', 'keyboard', FLRP_INTERACT.Key)

-- Close on resource stop so we never leave the draw loop / controls locked.
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and FLRPMenu.IsOpen() then FLRPMenu.Close() end
end)
