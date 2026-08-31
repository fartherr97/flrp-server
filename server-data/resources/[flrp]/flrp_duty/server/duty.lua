-- ==========================================================================
-- FLRP :: flrp_duty/server/duty.lua — duty logic
-- ==========================================================================
FLRPD = FLRPD or {}
FLRPD.State = { bySource = {} } -- source -> { department, onDuty }

local VALID_DEPTS = { BCSO = 'bcso', FHP = 'fhp', MPD = 'mpd' }

-- Normalize a department string to canonical UPPER or nil.
local function normalizeDept(dept)
  if type(dept) ~= 'string' then return nil end
  local up = string.upper(dept)
  if VALID_DEPTS[up] then return up end
  return nil
end

-- Does the player hold the role for this department? (authoritative)
local function playerHoldsDept(source, deptUpper)
  local roleKey = VALID_DEPTS[deptUpper]
  if not roleKey then return false end
  if not exports.flrp_permissions then return false end
  local ok, inGroup = pcall(function() return exports.flrp_permissions:IsInGroup(source, roleKey) end)
  return ok and inGroup == true
end

-- Load persisted duty on player load into cache (default: off/civilian).
function FLRPD.Load(source, playerId)
  local row = FLRP.DB.Single(
    'SELECT `department`, `on_duty` FROM `player_duty_state` WHERE `player_id` = ?', { playerId })
  local state = { department = row and row.department or nil, onDuty = row and row.on_duty == 1 or false }

  -- Safety: if persisted on-duty but the player no longer holds that dept role,
  -- force off duty (roles may have changed since last session).
  if state.onDuty and state.department and not playerHoldsDept(source, state.department) then
    state = { department = nil, onDuty = false }
    FLRPD._persist(playerId, nil, false)
  end
  FLRPD.State.bySource[source] = state
end

function FLRPD.Remove(source)
  FLRPD.State.bySource[source] = nil
end

function FLRPD.Get(source)
  return FLRPD.State.bySource[tonumber(source)] or { department = nil, onDuty = false }
end

function FLRPD._persist(playerId, deptUpper, onDuty)
  FLRP.DB.Update([[
    INSERT INTO `player_duty_state` (`player_id`, `department`, `on_duty`, `changed_at`)
    VALUES (?, ?, ?, CURRENT_TIMESTAMP)
    ON DUPLICATE KEY UPDATE `department` = VALUES(`department`),
      `on_duty` = VALUES(`on_duty`), `changed_at` = CURRENT_TIMESTAMP
  ]], { playerId, deptUpper, onDuty and 1 or 0 })
  FLRP.DB.Insert([[
    INSERT INTO `player_duty_log` (`player_id`, `department`, `on_duty`) VALUES (?, ?, ?)
  ]], { playerId, deptUpper, onDuty and 1 or 0 })
end

-- Set duty. Returns ok, errCode. Validates department role membership.
function FLRPD.SetDuty(source, department, onDuty)
  source = tonumber(source)
  local rec = exports.flrp_core:GetPlayer(source)
  if not rec then return false, 'no_player' end

  if not onDuty then
    return FLRPD.GoOffDuty(source)
  end

  local deptUpper = normalizeDept(department)
  if not deptUpper then return false, 'bad_department' end

  -- AUTHORITATIVE role check — cannot be bypassed by the client.
  if not playerHoldsDept(source, deptUpper) then
    FLRP.Logger.Warn('duty', 'Duty change denied (no dept role)', {
      source = source, department = deptUpper })
    return false, 'not_authorized'
  end

  FLRPD.State.bySource[source] = { department = deptUpper, onDuty = true }
  FLRPD._persist(rec.playerId, deptUpper, true)
  FLRP.Logger.Info('duty', 'On duty', { source = source, department = deptUpper })
  FLRP.Logger.Audit({
    actorPlayerId = rec.playerId, actorIdentifier = rec.license, actorDiscordId = rec.discordId,
    category = 'duty', action = 'on_duty', targetType = 'department', targetId = deptUpper,
    newValue = { onDuty = true, department = deptUpper } })
  TriggerClientEvent('flrp_duty:changed', source, deptUpper, true)
  return true
end

function FLRPD.GoOffDuty(source)
  source = tonumber(source)
  local rec = exports.flrp_core:GetPlayer(source)
  if not rec then return false, 'no_player' end
  local prev = FLRPD.Get(source)
  FLRPD.State.bySource[source] = { department = nil, onDuty = false }
  FLRPD._persist(rec.playerId, nil, false)
  FLRP.Logger.Info('duty', 'Off duty', { source = source, wasDept = prev.department })
  FLRP.Logger.Audit({
    actorPlayerId = rec.playerId, actorIdentifier = rec.license, actorDiscordId = rec.discordId,
    category = 'duty', action = 'off_duty', targetType = 'department', targetId = prev.department,
    oldValue = { onDuty = true, department = prev.department }, newValue = { onDuty = false } })
  TriggerClientEvent('flrp_duty:changed', source, nil, false)
  return true
end
