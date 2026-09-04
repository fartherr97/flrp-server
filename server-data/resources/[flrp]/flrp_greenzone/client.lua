-- ==========================================================================
-- FLRP :: flrp_greenzone/client.lua — enforcement + manager NUI
-- ==========================================================================

local zones       = {}     -- synced list of { id, name, x, y, z, radius, weapons, damage, vehicles }
local currentZone = nil
local invOn       = false
local previewing  = false
local isOpen      = false
local blips       = {}
local pending, seq = {}, 0

-- ---- bridge --------------------------------------------------------------
local function request(action, payload, cb)
  seq = seq + 1; pending[seq] = cb
  TriggerServerEvent('flrp_greenzone:req', action, payload or {}, seq)
end
RegisterNetEvent('flrp_greenzone:res', function(id, data)
  local cb = pending[id]; pending[id] = nil
  if cb then cb(data) end
end)

-- ---- blips ---------------------------------------------------------------
local function rebuildBlips()
  for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
  blips = {}
  for _, z in ipairs(zones) do
    local rb = AddBlipForRadius(z.x, z.y, z.z, z.radius)
    SetBlipColour(rb, FLRP_GZ.Blip.colour); SetBlipAlpha(rb, FLRP_GZ.Blip.alpha); SetBlipAsShortRange(rb, true)
    blips[#blips + 1] = rb
    local cb = AddBlipForCoord(z.x, z.y, z.z)
    SetBlipSprite(cb, FLRP_GZ.Blip.sprite); SetBlipColour(cb, FLRP_GZ.Blip.colour)
    SetBlipAsShortRange(cb, true); SetBlipScale(cb, 0.85)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(z.name); EndTextCommandSetBlipName(cb)
    blips[#blips + 1] = cb
  end
end

RegisterNetEvent('flrp_greenzone:zones', function(list)
  zones = (type(list) == 'table') and list or {}
  currentZone = nil
  if invOn then SetEntityInvincible(PlayerPedId(), false); invOn = false end
  rebuildBlips()
end)

-- ---- enforcement ---------------------------------------------------------
local WEAPON_BLOCK = { 24, 25, 47, 58, 140, 141, 142, 143, 257, 263, 264, 37 }
local UNARMED = GetHashKey('WEAPON_UNARMED')

CreateThread(function()
  while true do
    local wait = 500
    local ped = PlayerPedId()
    local pc  = GetEntityCoords(ped)

    local inZone
    for _, z in ipairs(zones) do
      if #(pc - vector3(z.x, z.y, z.z)) <= z.radius then inZone = z; break end
    end

    if inZone and (not currentZone or currentZone.id ~= inZone.id) then
      currentZone = inZone
      TriggerEvent('flrp_notify:toast', { title = inZone.name or 'Safe Zone', body = FLRP_GZ.EnterText, kind = 'ok' })
    elseif not inZone and currentZone then
      TriggerEvent('flrp_notify:toast', { title = currentZone.name or 'Safe Zone', body = FLRP_GZ.LeaveText, kind = 'info' })
      currentZone = nil
      if invOn then SetEntityInvincible(ped, false); invOn = false end
    elseif inZone then
      currentZone = inZone   -- keep latest (radius/options may have changed)
    end

    if currentZone then
      wait = 0
      if currentZone.damage then
        if not invOn then SetEntityInvincible(ped, true); invOn = true end
      elseif invOn then SetEntityInvincible(ped, false); invOn = false end

      if currentZone.weapons then
        DisablePlayerFiring(PlayerId(), true)
        for _, c in ipairs(WEAPON_BLOCK) do DisableControlAction(0, c, true) end
        if GetSelectedPedWeapon(ped) ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true) end
      end

      if currentZone.vehicles then
        DisableControlAction(0, 23, true)
        if IsPedInAnyVehicle(ped, false) then
          TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        end
      end
    end

    Wait(wait)
  end
end)

-- ---- preview markers (while the manager is open) -------------------------
CreateThread(function()
  while true do
    if previewing and #zones > 0 then
      for _, z in ipairs(zones) do
        DrawMarker(1, z.x, z.y, z.z - 1.0, 0, 0, 0, 0, 0, 0, z.radius * 2, z.radius * 2, 2.0,
          0, 180, 80, 90, false, false, 2, false, nil, nil, false)
      end
      Wait(0)
    else
      Wait(500)
    end
  end
end)

-- ---- manager NUI ---------------------------------------------------------
local function close()
  if not isOpen then return end
  isOpen = false; previewing = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

local function open()
  if isOpen then return close() end
  request('state', {}, function(state)
    if type(state) ~= 'table' or not state.ok then return end
    if not state.owner then
      return TriggerEvent('flrp_notify:toast', { title = 'Green Zones', kind = 'error', body = 'Ownership only.' })
    end
    isOpen = true; previewing = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state })
  end)
end

RegisterCommand(FLRP_GZ.Command, function() open() end, false)
RegisterCommand('gz', function() open() end, false)

-- create injects the caller's current coords; tp teleports locally.
RegisterNUICallback('create', function(data, cb)
  local c = GetEntityCoords(PlayerPedId())
  data = data or {}; data.x, data.y, data.z = c.x + 0.0, c.y + 0.0, c.z + 0.0
  request('create', data, function(res) cb(res or {}) end)
end)
RegisterNUICallback('tp', function(data, cb)
  local id = data and tonumber(data.id)
  for _, z in ipairs(zones) do
    if z.id == id then SetEntityCoords(PlayerPedId(), z.x, z.y, z.z, false, false, false, false); break end
  end
  cb({})
end)
for _, a in ipairs({ 'state', 'update', 'delete' }) do
  RegisterNUICallback(a, function(data, cb) request(a, data or {}, function(res) cb(res or {}) end) end)
end
RegisterNUICallback('refresh', function(_, cb) request('state', {}, function(res) cb(res or {}) end) end)
RegisterNUICallback('close', function(_, cb) close(); cb({}) end)

-- ---- sync on join --------------------------------------------------------
AddEventHandler('playerSpawned', function() TriggerServerEvent('flrp_greenzone:request') end)
CreateThread(function() Wait(3000); TriggerServerEvent('flrp_greenzone:request') end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  if invOn then SetEntityInvincible(PlayerPedId(), false) end
  for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
  if isOpen then SetNuiFocus(false, false) end
end)
