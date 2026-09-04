-- ==========================================================================
-- FLRP :: flrp_jail/client.lua — Jail Manager NUI + jailed/hospitalized state
-- ==========================================================================

local isOpen  = false
local pending, seq = {}, 0

local function request(action, payload, cb)
  seq = seq + 1
  pending[seq] = cb
  TriggerServerEvent('flrp_jail:req', action, payload or {}, seq)
end
RegisterNetEvent('flrp_jail:res', function(id, data)
  local cb = pending[id]; pending[id] = nil
  if cb then cb(data) end
end)

-- ---- manager NUI ---------------------------------------------------------
local function close()
  if not isOpen then return end
  isOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

local function open()
  if isOpen then return close() end
  request('state', {}, function(state)
    if type(state) ~= 'table' or not state.ok then return end
    local p = state.perms or {}
    if not (p.jail or p.hospitalize or p.leoHospitalize) then
      return TriggerEvent('flrp_notify:toast', { title = 'Jail', kind = 'error', body = 'You do not have access.' })
    end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state })
  end)
end

RegisterCommand('jail', function() open() end, false)
if FLRP_JAIL.Key ~= '' then RegisterKeyMapping('jail', 'FLRP: Jail Manager', 'keyboard', FLRP_JAIL.Key) end

-- NUI callbacks -> server, response handed straight back to the React fetch.
local function relay(name)
  RegisterNUICallback(name, function(data, cb) request(name, data or {}, function(res) cb(res or {}) end) end)
end
relay('jail'); relay('hospitalize'); relay('leoHospitalize'); relay('state')
RegisterNUICallback('refresh', function(_, cb) request('state', {}, function(res) cb(res or {}) end) end)
RegisterNUICallback('close', function(_, cb) close(); cb({}) end)

-- ---- shared HUD text -----------------------------------------------------
local function hud(str, y, c)
  SetTextFont(4); SetTextScale(0.0, 0.5)
  SetTextColour(c[1], c[2], c[3], c[4] or 255)
  SetTextEdge(1, 0, 0, 0, 205); SetTextOutline(); SetTextCentre(true)
  BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(str); EndTextCommandDisplayText(0.5, y)
end
local function mmss(rem) return ('%02d:%02d'):format(math.floor(rem / 60), rem % 60) end

local BLOCK = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 257, 263, 264, 23 }

-- ---- jailed state --------------------------------------------------------
local jailed, jailUntil, jailCell, jailRelease = false, 0, nil, nil

RegisterNetEvent('flrp_jail:enter', function(d)
  if type(d) ~= 'table' then return end
  jailUntil   = tonumber(d.untilTs) or (os.time() + 60)
  jailCell    = d.cell
  jailRelease = d.release
  jailed      = true
  local ped = PlayerPedId()
  RemoveAllPedWeapons(ped, true)
  if jailCell then SetEntityCoords(ped, jailCell.x, jailCell.y, jailCell.z, false, false, false, false); SetEntityHeading(ped, jailCell.w or 0.0) end
end)

RegisterNetEvent('flrp_jail:release', function()
  jailed = false
  local ped = PlayerPedId()
  if jailRelease then SetEntityCoords(ped, jailRelease.x, jailRelease.y, jailRelease.z, false, false, false, false); SetEntityHeading(ped, jailRelease.w or 0.0) end
  TriggerEvent('flrp_notify:toast', { title = 'Jail', kind = 'ok', body = 'You have been released.' })
end)

CreateThread(function()
  while true do
    if jailed then
      local ped = PlayerPedId()
      DisablePlayerFiring(PlayerId(), true)
      for _, c in ipairs(BLOCK) do DisableControlAction(0, c, true) end
      SetPlayerWantedLevel(PlayerId(), 0, false); SetPlayerWantedLevelNow(PlayerId(), false)
      if jailCell then
        local d = #(GetEntityCoords(ped) - vector3(jailCell.x, jailCell.y, jailCell.z))
        if d > FLRP_JAIL.CellRadius then SetEntityCoords(ped, jailCell.x, jailCell.y, jailCell.z, false, false, false, false) end
      end
      hud('~r~JAILED~s~  ' .. mmss(math.max(0, jailUntil - os.time())), 0.94, { 236, 240, 244, 255 })
      Wait(0)
    else
      Wait(400)
    end
  end
end)

-- ---- hospitalized state --------------------------------------------------
local hosp, hospUntil, hospCoords, hospLabel = false, 0, nil, ''

RegisterNetEvent('flrp_jail:hospitalize', function(d)
  if type(d) ~= 'table' then return end
  hospUntil  = tonumber(d.untilTs) or (os.time() + 120)
  hospCoords = d.coords
  hospLabel  = tostring(d.label or 'Hospital')
  hosp       = true
  local ped = PlayerPedId()
  if hospCoords then SetEntityCoords(ped, hospCoords.x, hospCoords.y, hospCoords.z, false, false, false, false); SetEntityHeading(ped, hospCoords.w or 0.0) end
end)

CreateThread(function()
  while true do
    if hosp then
      if os.time() >= hospUntil then
        hosp = false
        TriggerEvent('flrp_notify:toast', { title = 'Hospital', kind = 'ok', body = 'You have recovered. Take it easy.' })
      else
        local ped = PlayerPedId()
        DisablePlayerFiring(PlayerId(), true)
        for _, c in ipairs(BLOCK) do DisableControlAction(0, c, true) end
        if hospCoords and #(GetEntityCoords(ped) - vector3(hospCoords.x, hospCoords.y, hospCoords.z)) > 30.0 then
          SetEntityCoords(ped, hospCoords.x, hospCoords.y, hospCoords.z, false, false, false, false)
        end
        hud('~b~HOSPITALIZED~s~  ' .. hospLabel .. '  ' .. mmss(math.max(0, hospUntil - os.time())), 0.94, { 236, 240, 244, 255 })
        Wait(0)
      end
    else
      Wait(400)
    end
  end
end)

-- ---- persistence: re-apply an active jail after a relog -------------------
AddEventHandler('playerSpawned', function() TriggerServerEvent('flrp_jail:ready') end)
CreateThread(function() Wait(4000); TriggerServerEvent('flrp_jail:ready') end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
