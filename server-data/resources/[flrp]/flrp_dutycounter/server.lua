-- ==========================================================================
-- FLRP :: flrp_dutycounter/server.lua
-- ==========================================================================
-- Broadcasts live on-duty counts to the HUD counter:
--   LEO   — players on duty for a LEO department, read from nex-duty via
--           exports.flrp_duty:IsOnDuty(src) (BSO / FHP / MPD).
--   STAFF — interim: a `/sd` toggle (flrp.staff.moderate) marks a staffer
--           on/off. The future EUP staff-vest system can drive the same state
--           by calling exports.flrp_dutycounter:SetStaffOnDuty(src, bool).
-- ==========================================================================

local staffOnDuty = {} -- [src] = true

local function countLeo()
  local n = 0
  for _, pid in ipairs(GetPlayers()) do
    pid = tonumber(pid)
    local ok, on = pcall(function() return exports.flrp_duty:IsOnDuty(pid) end)
    if ok and on then n = n + 1 end
  end
  return n
end

local function countStaff()
  local n = 0
  for src in pairs(staffOnDuty) do
    if GetPlayerName(src) then n = n + 1 else staffOnDuty[src] = nil end
  end
  return n
end

local last = { leo = 0, staff = 0, seeded = false }

local function broadcast(force)
  local leo, staff = countLeo(), countStaff()
  if force or not last.seeded or leo ~= last.leo or staff ~= last.staff then
    last.leo, last.staff, last.seeded = leo, staff, true
    TriggerClientEvent('flrp_dutycounter:update', -1, { leo = leo, staff = staff })
  end
end

-- Poll (duty is read-only from nex-duty's table, so we re-count on a timer).
CreateThread(function()
  while true do
    Wait(5000)
    broadcast(false)
  end
end)

-- A client asking for the current values (on join / resource start).
RegisterNetEvent('flrp_dutycounter:request', function()
  TriggerClientEvent('flrp_dutycounter:update', source, { leo = last.leo, staff = last.staff })
end)

-- Interim staff on/off-duty toggle.
RegisterCommand('sd', function(src)
  if type(src) ~= 'number' or src <= 0 then return end
  if not IsPlayerAceAllowed(src, 'flrp.staff.moderate') then
    TriggerClientEvent('chat:addMessage', src, { color = { 200, 60, 60 }, args = { 'SYSTEM', 'Staff only.' } })
    return
  end
  if staffOnDuty[src] then staffOnDuty[src] = nil else staffOnDuty[src] = true end
  local on = staffOnDuty[src] == true
  TriggerClientEvent('chat:addMessage', src, {
    color = { 0, 191, 196 },
    args = { 'STAFF DUTY', on and 'You are now ON staff duty.' or 'You are now OFF staff duty.' },
  })
  broadcast(true)
end, false)

-- Public hook for the future EUP staff-vest system.
exports('SetStaffOnDuty', function(src, on)
  src = tonumber(src)
  if not src then return end
  if on then staffOnDuty[src] = true else staffOnDuty[src] = nil end
  broadcast(true)
end)

AddEventHandler('playerDropped', function()
  local src = source
  if staffOnDuty[src] then staffOnDuty[src] = nil end
  broadcast(true)
end)
