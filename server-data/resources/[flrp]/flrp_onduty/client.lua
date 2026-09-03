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
  if isOpen then close() else open() end
end, false)
RegisterKeyMapping(FLRP_ONDUTY.Command, 'FLRP: Duty menu', 'keyboard', FLRP_ONDUTY.Key)
TriggerEvent('chat:addSuggestion', '/' .. FLRP_ONDUTY.Command, 'Open the department duty menu', {
  { name = 'units', help = "'units' — see who's on duty in every department" },
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

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
