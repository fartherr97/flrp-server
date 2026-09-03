-- ==========================================================================
-- FLRP :: flrp_onduty/server.lua — duty state, access, roster table
-- ==========================================================================
-- In-memory state is the source of truth; `flrp_duty_members` mirrors it as
-- a LIVE registry (cleared on boot, row removed on off-duty / disconnect) so
-- every consumer that reads duty from the DB keeps working unchanged.
-- `flrp_duty_sessions` keeps a history row per duty session (for hours later).
-- Client <-> server: TriggerServerEvent('flrp_onduty:req', action, payload, id)
-- answered by TriggerClientEvent('flrp_onduty:res', id, result).
-- ==========================================================================

local CFG    = FLRP_ONDUTY
local onDuty = {}   -- src -> { entity, rank, callsign, license, discord, name, since, sessionId }
local ready  = false

-- ---- helpers -------------------------------------------------------------
local function idOf(src, prefix)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, #prefix) == prefix then return id:sub(#prefix + 1) end
  end
  return nil
end

local function dept(id)
  for _, d in ipairs(CFG.Departments) do if d.id == id then return d end end
  return nil
end

local function rankOf(d, id)
  for _, r in ipairs(d.ranks) do if r.id == id then return r end end
  return nil
end

local function toast(src, title, body, kind)
  TriggerClientEvent('flrp_notify:toast', src, { title = title, body = body, kind = kind or 'info' })
end

-- Which departments/ranks this player may join.
local function available(src)
  local override = IsPlayerAceAllowed(src, CFG.OverrideAce)
  local out = {}
  for _, d in ipairs(CFG.Departments) do
    local ranks = {}
    for _, r in ipairs(d.ranks) do
      if override or (r.ace and IsPlayerAceAllowed(src, r.ace)) then
        ranks[#ranks + 1] = { id = r.id, label = r.label }
      end
    end
    if #ranks > 0 then
      out[#out + 1] = { id = d.id, label = d.label, short = d.short, colour = d.colour,
                        requireCallsign = d.requireCallsign and true or false, ranks = ranks }
    end
  end
  return out
end

local function cleanCallsign(cs)
  cs = tostring(cs or ''):upper():gsub('[^%w%-]', '')
  if #cs > CFG.CallsignMax then cs = cs:sub(1, CFG.CallsignMax) end
  return cs
end

local function callsignTaken(entity, cs, exceptSrc)
  for s, d in pairs(onDuty) do
    if s ~= exceptSrc and d.entity == entity and d.callsign == cs then return true end
  end
  return false
end

-- Best-effort nex-hud job display (escrowed export; signature may differ — never fatal).
local function hud(src, data)
  pcall(function() exports['nex-hud']:updateJobData(src, data) end)
end

-- ---- DB ------------------------------------------------------------------
local function ensureTables()
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `flrp_duty_members` (
      `license`    VARCHAR(64)  NOT NULL,
      `entity`     VARCHAR(32)  NOT NULL,
      `rank`       VARCHAR(32)  NOT NULL,
      `callsign`   VARCHAR(16)  NULL,
      `discord`    VARCHAR(32)  NULL,
      `name`       VARCHAR(100) NOT NULL,
      `started_at` INT UNSIGNED NOT NULL,
      PRIMARY KEY (`license`),
      KEY `idx_entity` (`entity`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `flrp_duty_sessions` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `license`    VARCHAR(64)  NOT NULL,
      `name`       VARCHAR(100) NOT NULL,
      `entity`     VARCHAR(32)  NOT NULL,
      `rank`       VARCHAR(32)  NOT NULL,
      `callsign`   VARCHAR(16)  NULL,
      `started_at` INT UNSIGNED NOT NULL,
      `ended_at`   INT UNSIGNED NULL,
      `seconds`    INT UNSIGNED NULL,
      PRIMARY KEY (`id`), KEY `idx_lic` (`license`), KEY `idx_start` (`started_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  -- live registry: nobody is on duty at boot; close any dangling sessions
  FLRP.DB.Query('DELETE FROM `flrp_duty_members`')
  FLRP.DB.Query('UPDATE `flrp_duty_sessions` SET `ended_at`=`started_at`, `seconds`=0 WHERE `ended_at` IS NULL')
end

-- ---- state changes -------------------------------------------------------
local function goOn(src, entity, rankId, callsign)
  local d = dept(entity)
  if not d then return false, 'Unknown department.' end
  local avail
  for _, a in ipairs(available(src)) do if a.id == entity then avail = a end end
  if not avail then return false, "You don't have access to " .. d.short .. '.' end
  local r
  for _, ar in ipairs(avail.ranks) do if ar.id == rankId then r = rankOf(d, rankId) end end
  if not r then return false, "You can't go on duty at that rank." end

  local cs = cleanCallsign(callsign)
  if d.requireCallsign and cs == '' then return false, 'Enter a callsign first.' end
  if cs ~= '' and callsignTaken(entity, cs, src) then return false, ('Callsign %s is already in use for %s.'):format(cs, d.short) end

  if onDuty[src] then goOffInternal(src, 'switch') end

  local lic = idOf(src, 'license:')
  if not lic then return false, 'Could not read your license.' end
  local t = os.time()
  local name = GetPlayerName(src) or ('Player ' .. src)
  local discord = idOf(src, 'discord:')
  local sid = FLRP.DB.Insert('INSERT INTO `flrp_duty_sessions` (`license`,`name`,`entity`,`rank`,`callsign`,`started_at`) VALUES (?,?,?,?,?,?)',
    { lic, name, entity, r.id, cs ~= '' and cs or nil, t })
  FLRP.DB.Query('REPLACE INTO `flrp_duty_members` (`license`,`entity`,`rank`,`callsign`,`discord`,`name`,`started_at`) VALUES (?,?,?,?,?,?,?)',
    { lic, entity, r.id, cs ~= '' and cs or nil, discord, name, t })

  onDuty[src] = { entity = entity, rank = r.id, callsign = cs, license = lic, discord = discord, name = name, since = t, sessionId = sid }
  TriggerClientEvent('flrp_onduty:loadout', src, d.loadout and CFG.Loadouts[d.loadout] or nil)
  TriggerClientEvent('flrp_onduty:changed', src, onDuty[src])
  hud(src, { job = entity, label = d.short, name = d.label, rank = r.label, callsign = cs, onDuty = true })
  TriggerEvent('flrp_onduty:server:on', src, onDuty[src])
  toast(src, d.short .. ' · ON DUTY', ('%s%s — stay safe out there.'):format(r.label, cs ~= '' and (' · ' .. cs) or ''), 'ok')
  pcall(function() exports.flrp_duty:Invalidate(src) end)
  return true
end

function goOffInternal(src, why)
  local d = onDuty[src]
  if not d then return false end
  local t = os.time()
  pcall(function()
    FLRP.DB.Update('DELETE FROM `flrp_duty_members` WHERE `license`=?', { d.license })
    if d.sessionId then
      FLRP.DB.Update('UPDATE `flrp_duty_sessions` SET `ended_at`=?, `seconds`=? WHERE `id`=?', { t, t - d.since, d.sessionId })
    end
  end)
  onDuty[src] = nil
  if why ~= 'dropped' then
    if CFG.RemoveWeaponsOffDuty then TriggerClientEvent('flrp_onduty:loadout', src, nil) end
    TriggerClientEvent('flrp_onduty:changed', src, nil)
    hud(src, nil)
  end
  TriggerEvent('flrp_onduty:server:off', src, d, why)
  pcall(function() exports.flrp_duty:Invalidate(src) end)
  return true, d
end

local function goOff(src)
  local ok, d = goOffInternal(src, 'manual')
  if not ok then return false, 'You are not on duty.' end
  local dd = dept(d.entity)
  toast(src, (dd and dd.short or d.entity) .. ' · OFF DUTY', 'You have gone off duty.', 'info')
  return true
end

-- ---- exports -------------------------------------------------------------
function IsOnDuty(src) return onDuty[tonumber(src)] ~= nil end
function GetDuty(src) return onDuty[tonumber(src)] end
function GetAll()
  local out = {}
  for s, d in pairs(onDuty) do out[#out + 1] = { src = s, entity = d.entity, rank = d.rank, callsign = d.callsign, name = d.name, since = d.since } end
  return out
end
function SetOffDuty(src) return (goOffInternal(tonumber(src), 'forced')) end

-- ---- bridge --------------------------------------------------------------
local H = {}

function H.state(src)
  local me = onDuty[src]
  local meView
  if me then
    local d = dept(me.entity); local r = d and rankOf(d, me.rank)
    meView = { entity = me.entity, short = d and d.short or me.entity, label = d and d.label or me.entity,
               colour = d and d.colour, rank = me.rank, rankLabel = r and r.label or me.rank,
               callsign = me.callsign, since = me.since }
  end
  local counts = {}
  for _, d in pairs(onDuty) do counts[d.entity] = (counts[d.entity] or 0) + 1 end
  return { ok = true, onDuty = meView, available = available(src), counts = counts,
           logo = GetConvar('flrp_reports_logo', CFG.Logo), serverName = CFG.ServerName,
           key = CFG.Key, callsignMax = CFG.CallsignMax, now = os.time() }
end

function H.goOn(src, p)
  local ok, err = goOn(src, tostring(p.entity or ''), tostring(p.rank or ''), p.callsign)
  if not ok then return { ok = false, error = err } end
  return H.state(src)
end

function H.goOff(src)
  local ok, err = goOff(src)
  if not ok then return { ok = false, error = err } end
  return H.state(src)
end

RegisterNetEvent('flrp_onduty:req', function(action, payload, reqId)
  local src = source
  if type(src) ~= 'number' or src <= 0 then return end
  payload = type(payload) == 'table' and payload or {}
  local res
  if not ready then res = { ok = false, error = 'Duty system is starting — try again in a moment.' }
  else
    local h = H[tostring(action)]
    if not h then res = { ok = false, error = 'Unknown action.' }
    else
      local ok, r = pcall(h, src, payload)
      if ok and type(r) == 'table' then res = r
      else print(('[flrp_onduty] %s failed: %s'):format(tostring(action), tostring(r))); res = { ok = false, error = 'Server error.' } end
    end
  end
  TriggerClientEvent('flrp_onduty:res', src, reqId, res)
end)

-- /offduty <id> — force a unit off duty
RegisterCommand('offduty', function(src, args)
  if type(src) == 'number' and src > 0 and not IsPlayerAceAllowed(src, CFG.ForceOffAce) then
    toast(src, 'DUTY', 'Admins only.', 'error'); return
  end
  local target = tonumber(args and args[1])
  if not target or not onDuty[target] then
    if src > 0 then toast(src, 'DUTY', 'Usage: /offduty <server id> (must be on duty).', 'error') end
    return
  end
  local d = onDuty[target]
  goOffInternal(target, 'forced')
  toast(target, 'DUTY', 'You were taken off duty by staff.', 'error')
  if src > 0 then toast(src, 'DUTY', ('%s taken off duty.'):format(d.name), 'ok') end
end, false)

AddEventHandler('playerDropped', function()
  local src = source
  if onDuty[src] then goOffInternal(src, 'dropped') end
end)

-- ---- boot ----------------------------------------------------------------
CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  local ok, err = pcall(ensureTables)
  if not ok then print('[flrp_onduty] table setup failed: ' .. tostring(err)) end
  ready = true
  print(('[flrp_onduty] ready — %d department(s), /%s or %s'):format(#CFG.Departments, CFG.Command, CFG.Key))
end)
