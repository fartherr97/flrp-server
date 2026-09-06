-- ==========================================================================
-- FLRP :: flrp_onduty/client.lua — menu keybind, NUI focus, loadout apply
-- ==========================================================================

local isOpen, pending, seq = false, {}, 0

local function request(action, payload, cb)
  seq = seq + 1; pending[seq] = cb
  TriggerServerEvent('flrp_onduty:req', action, payload or {}, seq)
end
RegisterNetEvent('flrp_onduty:res', function(id, data)
  local cb = pending[id]; pending[id] = nil
  if cb then cb(data) end
end)

local function close()
  isOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

local function open(view)
  request('state', {}, function(state)
    if not state or not state.ok then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state, view = view })
  end)
end

RegisterCommand(FLRP_ONDUTY.Command, function(_, args)
  local a = (args and args[1] or ''):lower()
  if a == 'units' or a == 'list' then
    if isOpen then close() end
    return open('units')
  end
  if a == 'config' or a == 'setup' or a == 'edit' then
    if isOpen then close() end
    return open('config')          -- Ownership editor (server gates access)
  end
  if isOpen then close() else open() end
end, false)
RegisterKeyMapping(FLRP_ONDUTY.Command, 'FLRP: Duty menu', 'keyboard', FLRP_ONDUTY.Key)
TriggerEvent('chat:addSuggestion', '/' .. FLRP_ONDUTY.Command, 'Open the department duty menu', {
  { name = 'units', help = "'units' — see who's on duty in every department" },
  { name = 'config', help = "'config' — Ownership: add / edit / remove departments" },
})

RegisterNUICallback('close', function(_, cb) close(); cb({}) end)
RegisterNUICallback('req', function(data, cb)
  request(data and data.action, data and data.payload, function(res) cb(res or { ok = false, error = 'No response.' }) end)
end)

-- Loadout: nil = strip weapons; table = give this set.
RegisterNetEvent('flrp_onduty:loadout', function(weapons)
  local ped = PlayerPedId()
  RemoveAllPedWeapons(ped, true)
  if type(weapons) ~= 'table' then return end
  for _, w in ipairs(weapons) do
    local hash = GetHashKey(w.name)
    GiveWeaponToPed(ped, hash, w.ammo or 0, false, false)
    for _, c in ipairs(w.attachments or {}) do
      GiveWeaponComponentToPed(ped, hash, GetHashKey(c))
    end
  end
  SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
end)

-- Server pushes the new duty state (also refreshes the menu if it's open).
RegisterNetEvent('flrp_onduty:changed', function()
  if isOpen then
    request('state', {}, function(state)
      if state and state.ok then SendNUIMessage({ action = 'state', state = state }) end
    end)
  end
end)

-- ==========================================================================
-- On-duty status HUD — FLRP's own card (dept · rank · callsign + live timer).
-- Players reposition/resize it with `/hud`; the layout persists per machine.
-- ==========================================================================
local HUD       = FLRP_ONDUTY.Hud or {}
local hudEditing = false

-- Saved layout (KVP), falling back to the config default on first run.
local function hudLayout()
  local d = HUD.Default or { x = 1.5, y = 22.0, scale = 1.0 }
  local function f(key, def)
    local v = GetResourceKvpFloat('flrp_onduty:hud:' .. key)
    return (v ~= nil and v ~= 0.0) and v or def
  end
  return { x = f('x', d.x), y = f('y', d.y), scale = f('scale', d.scale) }
end

local function pushLayout()
  SendNUIMessage({ action = 'hudLayout', layout = hudLayout() })
end

local function endHudEdit()
  if not hudEditing then return end
  hudEditing = false
  SetNuiFocus(false, false)
end

-- Server tells us the player's duty status changed (table = on duty, nil = off).
RegisterNetEvent('flrp_onduty:hud', function(duty)
  if HUD.Enabled == false then return end
  SendNUIMessage({ action = 'hud', duty = duty or false, showTimer = HUD.ShowTimer ~= false })
end)

-- /hud — enter layout edit mode (drag to move, +/- to resize, save/reset).
RegisterCommand(HUD.Command or 'hud', function()
  if HUD.Enabled == false then return end
  if isOpen then close() end          -- the menu and HUD-edit both want NUI focus
  hudEditing = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'hudEdit', on = true, layout = hudLayout() })
end, false)
TriggerEvent('chat:addSuggestion', '/' .. (HUD.Command or 'hud'), 'Move & resize your on-duty status card')

-- NUI: player saved a new layout (persist it and leave edit mode).
RegisterNUICallback('hudSave', function(data, cb)
  local x = tonumber(data and data.x)
  local y = tonumber(data and data.y)
  local s = tonumber(data and data.scale)
  if x then SetResourceKvpFloat('flrp_onduty:hud:x', x + 0.0) end
  if y then SetResourceKvpFloat('flrp_onduty:hud:y', y + 0.0) end
  if s then SetResourceKvpFloat('flrp_onduty:hud:scale', s + 0.0) end
  endHudEdit()
  cb({ ok = true })
end)

-- NUI: player cancelled (restore the saved layout) or reset to default.
RegisterNUICallback('hudCancel', function(_, cb) endHudEdit(); pushLayout(); cb({ ok = true }) end)
RegisterNUICallback('hudReset', function(_, cb)
  DeleteResourceKvp('flrp_onduty:hud:x')
  DeleteResourceKvp('flrp_onduty:hud:y')
  DeleteResourceKvp('flrp_onduty:hud:scale')
  pushLayout()
  cb({ ok = true })
end)

-- Apply the saved layout once the NUI is up (and whenever this resource starts),
-- then re-sync the card in case we restarted while the player was on duty.
CreateThread(function()
  Wait(500)
  pushLayout()
  if HUD.Enabled == false then return end
  request('state', {}, function(state)
    local me = state and state.ok and state.onDuty
    if me then
      SendNUIMessage({ action = 'hud', showTimer = HUD.ShowTimer ~= false,
        duty = { dept = me.short, rank = me.rankLabel, callsign = me.callsign or '', since = me.since } })
    end
  end)
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and (isOpen or hudEditing) then SetNuiFocus(false, false) end
end)
