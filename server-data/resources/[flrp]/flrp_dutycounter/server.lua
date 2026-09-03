-- ==========================================================================
-- FLRP :: flrp_dutycounter/server.lua
-- ==========================================================================
-- Broadcasts live on-duty counts to the HUD counter:
--   LEO   — players on duty for a LEO department, read from flrp_onduty via
--           exports.flrp_duty:IsOnDuty(src) (BSO / FHP / MPD).
--   STAFF — interim: a `/sd` toggle (flrp.staff.moderate) marks a staffer
--           on/off. The future EUP staff-vest system can drive the same state
--           by calling exports.flrp_dutycounter:SetStaffOnDuty(src, bool).
-- ==========================================================================

local staffOnDuty = {} -- [src] = true

-- LEO = connected players with a live flrp_duty_members row for an FLRP
-- department (BSO / FHP / MPD), read via flrp_duty's roster export.
local function countLeo()
  local ok, roster = pcall(function() return exports.flrp_duty:GetOnDutyRoster() end)
  if not ok or type(roster) ~= 'table' then return 0 end
  local n = 0
  for _, u in ipairs(roster) do
    if u.online and u.department then n = n + 1 end
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

-- Poll (duty is read from the registry table, so we re-count on a timer).
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

-- Staff on/off state is owned by flrp_staffactivity (the /vest toggle) and
-- pushed here through the SetStaffOnDuty export below.

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
