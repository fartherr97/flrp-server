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

-- Subdivision lookup. Returns the matching subdivision, or the department's
-- first subdivision as the default, or nil if the dept has none.
local function subOf(d, id)
  if not d.subdivisions or #d.subdivisions == 0 then return nil end
  for _, s in ipairs(d.subdivisions) do if s.id == id then return s end end
  return d.subdivisions[1]
end

-- Resolved map-blip colour index for a dept + subdivision (subdivision wins).
local function blipFor(d, sub)
  if sub and sub.blip ~= nil then return sub.blip end
  return d.blip
end

local function toast(src, title, body, kind)
  TriggerClientEvent('flrp_notify:toast', src, { title = title, body = body, kind = kind or 'info' })
end

-- Which departments/ranks/subdivisions this player may join.
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
    -- Subdivisions the player may pick: ungated ones for everyone in the dept,
    -- gated ones only with the ace (Override sees all).
    local subs = {}
    for _, s in ipairs(d.subdivisions or {}) do
      if override or not s.ace or IsPlayerAceAllowed(src, s.ace) then
        subs[#subs + 1] = { id = s.id, label = s.label, colour = s.colour or d.colour }
      end
    end
    if #ranks > 0 then
      out[#out + 1] = { id = d.id, label = d.label, short = d.short, colour = d.colour,
                        requireCallsign = d.requireCallsign and true or false,
                        ranks = ranks, subdivisions = subs }
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
-- Add a column only if it isn't already there (existing installs predate the
-- subdivision/blip columns; MySQL has no portable ADD COLUMN IF NOT EXISTS).
local function addColumn(tbl, col, ddl)
  local n = FLRP.DB.Scalar(
    'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE table_schema=DATABASE() AND table_name=? AND column_name=?',
    { tbl, col })
  if (tonumber(n) or 0) == 0 then
    FLRP.DB.Query(('ALTER TABLE `%s` ADD COLUMN %s'):format(tbl, ddl))
  end
end

local function ensureTables()
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `flrp_duty_members` (
      `license`     VARCHAR(64)  NOT NULL,
      `entity`      VARCHAR(32)  NOT NULL,
      `rank`        VARCHAR(32)  NOT NULL,
      `subdivision` VARCHAR(32)  NULL,
      `blip`        INT          NULL,
      `callsign`    VARCHAR(16)  NULL,
      `discord`     VARCHAR(32)  NULL,
      `name`        VARCHAR(100) NOT NULL,
      `started_at`  INT UNSIGNED NOT NULL,
      PRIMARY KEY (`license`),
      KEY `idx_entity` (`entity`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `flrp_duty_sessions` (
      `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `license`     VARCHAR(64)  NOT NULL,
      `name`        VARCHAR(100) NOT NULL,
      `entity`      VARCHAR(32)  NOT NULL,
      `rank`        VARCHAR(32)  NOT NULL,
      `subdivision` VARCHAR(32)  NULL,
      `callsign`    VARCHAR(16)  NULL,
      `started_at`  INT UNSIGNED NOT NULL,
      `ended_at`    INT UNSIGNED NULL,
      `seconds`     INT UNSIGNED NULL,
      PRIMARY KEY (`id`), KEY `idx_lic` (`license`), KEY `idx_start` (`started_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  -- migrate older installs that lack the newer columns (tables now exist)
  addColumn('flrp_duty_members',  'subdivision', '`subdivision` VARCHAR(32) NULL AFTER `rank`')
  addColumn('flrp_duty_members',  'blip',        '`blip` INT NULL AFTER `subdivision`')
  addColumn('flrp_duty_sessions', 'subdivision', '`subdivision` VARCHAR(32) NULL AFTER `rank`')
  -- editable departments config (single JSON row, seeded from config.lua)
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `flrp_duty_config` (
      `id`         INT UNSIGNED NOT NULL,
      `json`       LONGTEXT     NOT NULL,
      `updated_by` VARCHAR(100) NULL,
      `updated_at` INT UNSIGNED NOT NULL,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  -- live registry: nobody is on duty at boot; close any dangling sessions
  FLRP.DB.Query('DELETE FROM `flrp_duty_members`')
  FLRP.DB.Query('UPDATE `flrp_duty_sessions` SET `ended_at`=`started_at`, `seconds`=0 WHERE `ended_at` IS NULL')
end

-- ---- state changes -------------------------------------------------------
local function goOn(src, entity, rankId, subId, callsign)
  local d = dept(entity)
  if not d then return false, 'Unknown department.' end
  local avail
  for _, a in ipairs(available(src)) do if a.id == entity then avail = a end end
  if not avail then return false, "You don't have access to " .. d.short .. '.' end
  local r
  for _, ar in ipairs(avail.ranks) do if ar.id == rankId then r = rankOf(d, rankId) end end
  if not r then return false, "You can't go on duty at that rank." end

  -- Resolve + authorise the subdivision (if the dept has any). A subdivision the
  -- player can't see falls back to the dept default rather than erroring.
  local sub
  if d.subdivisions and #d.subdivisions > 0 then
    local allowed = false
    for _, as in ipairs(avail.subdivisions or {}) do if as.id == subId then allowed = true end end
    sub = subOf(d, allowed and subId or nil)   -- nil -> first (default) subdivision
  end

  local cs = cleanCallsign(callsign)
  if d.requireCallsign and cs == '' then return false, 'Enter a callsign first.' end
  if cs ~= '' and callsignTaken(entity, cs, src) then return false, ('Callsign %s is already in use for %s.'):format(cs, d.short) end

  if onDuty[src] then goOffInternal(src, 'switch') end

  local lic = idOf(src, 'license:')
  if not lic then return false, 'Could not read your license.' end
  local t = os.time()
  local name = GetPlayerName(src) or ('Player ' .. src)
  local discord = idOf(src, 'discord:')
  local subKey = sub and sub.id or nil
  local blip   = blipFor(d, sub)
  local sid = FLRP.DB.Insert('INSERT INTO `flrp_duty_sessions` (`license`,`name`,`entity`,`rank`,`subdivision`,`callsign`,`started_at`) VALUES (?,?,?,?,?,?,?)',
    { lic, name, entity, r.id, subKey, cs ~= '' and cs or nil, t })
  FLRP.DB.Query('REPLACE INTO `flrp_duty_members` (`license`,`entity`,`rank`,`subdivision`,`blip`,`callsign`,`discord`,`name`,`started_at`) VALUES (?,?,?,?,?,?,?,?,?)',
    { lic, entity, r.id, subKey, blip, cs ~= '' and cs or nil, discord, name, t })

  onDuty[src] = { entity = entity, rank = r.id, subdivision = subKey, blip = blip, callsign = cs,
                  license = lic, discord = discord, name = name, since = t, sessionId = sid }
  TriggerClientEvent('flrp_onduty:loadout', src, d.loadout and CFG.Loadouts[d.loadout] or nil)
  TriggerClientEvent('flrp_onduty:changed', src, onDuty[src])
  hud(src, { job = entity, label = d.short, name = d.label, rank = r.label, callsign = cs, onDuty = true })
  TriggerEvent('flrp_onduty:server:on', src, onDuty[src])
  local subTxt = sub and sub.id ~= (d.subdivisions and d.subdivisions[1] and d.subdivisions[1].id) and (' · ' .. sub.label) or ''
  toast(src, d.short .. ' · ON DUTY', ('%s%s%s — stay safe out there.'):format(r.label, subTxt, cs ~= '' and (' · ' .. cs) or ''), 'ok')
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
    local s = d and me.subdivision and subOf(d, me.subdivision) or nil
    meView = { entity = me.entity, short = d and d.short or me.entity, label = d and d.label or me.entity,
               colour = (s and s.colour) or (d and d.colour), rank = me.rank, rankLabel = r and r.label or me.rank,
               subdivision = me.subdivision, subLabel = s and s.label or nil,
               callsign = me.callsign, since = me.since }
  end
  local counts = {}
  for _, d in pairs(onDuty) do counts[d.entity] = (counts[d.entity] or 0) + 1 end
  return { ok = true, onDuty = meView, available = available(src), counts = counts,
           logo = GetConvar('flrp_reports_logo', CFG.Logo), serverName = CFG.ServerName,
           key = CFG.Key, callsignMax = CFG.CallsignMax, now = os.time() }
end

-- Units board: every department with who's on duty.
local function canViewUnits(src)
  for _, a in ipairs(CFG.UnitsAces or {}) do
    if IsPlayerAceAllowed(src, a) then return true end
  end
  return false
end

function H.units(src)
  if not canViewUnits(src) then return { ok = false, error = 'Units board is for on-duty personnel and staff.' } end
  local byDept, total = {}, 0
  for s, d in pairs(onDuty) do
    byDept[d.entity] = byDept[d.entity] or {}
    local dd = dept(d.entity); local r = dd and rankOf(dd, d.rank)
    local sub = dd and d.subdivision and subOf(dd, d.subdivision) or nil
    table.insert(byDept[d.entity], { src = s, name = d.name, callsign = d.callsign,
      rank = r and r.label or d.rank, sub = sub and sub.label or nil, since = d.since })
    total = total + 1
  end
  local depts = {}
  for _, d in ipairs(CFG.Departments) do
    local list = byDept[d.id] or {}
    table.sort(list, function(a, b) return (a.callsign or 'zzz') < (b.callsign or 'zzz') end)
    depts[#depts + 1] = { id = d.id, label = d.label, short = d.short, colour = d.colour, count = #list, units = list }
  end
  return { ok = true, depts = depts, total = total, now = os.time() }
end

function H.goOn(src, p)
  local ok, err = goOn(src, tostring(p.entity or ''), tostring(p.rank or ''),
    p.subdivision and tostring(p.subdivision) or nil, p.callsign)
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

-- ==========================================================================
-- Editable departments config (DB-backed; config.lua is the seed/fallback)
-- ==========================================================================
-- The departments list can be edited live via /duty config (Ownership). It is
-- persisted as one JSON row in flrp_duty_config and loaded over the config.lua
-- defaults on boot. Every read (dept/available/etc.) already goes through
-- CFG.Departments, so reassigning it hot-applies changes. If the DB row is
-- missing or invalid we keep the config.lua defaults — the menu never breaks.

local DEFAULT_DEPARTMENTS = CFG.Departments   -- the config.lua seed (kept as fallback)

local function slug(s)
  s = tostring(s or ''):lower():gsub('[^%w]+', '-'):gsub('^%-+', ''):gsub('%-+$', '')
  return s
end

-- Coerce arbitrary editor input into a clean, safe departments array. Anything
-- malformed is dropped rather than trusted; returns nil only if not a table.
local function sanitizeDepartments(input)
  if type(input) ~= 'table' then return nil end
  local out, seen = {}, {}
  for _, d in ipairs(input) do
    if type(d) == 'table' then
      local id = slug(d.id ~= '' and d.id or d.short or d.label)
      if id ~= '' and not seen[id] then
        seen[id] = true
        local dept = {
          id = id,
          label = tostring(d.label or id):sub(1, 64),
          short = tostring(d.short or id:upper()):sub(1, 8),
          colour = tostring(d.colour or '#8a8f98'):sub(1, 9),
          blip = tonumber(d.blip) or 0,
          requireCallsign = d.requireCallsign and true or false,
          loadout = (d.loadout ~= nil and d.loadout ~= '') and tostring(d.loadout) or nil,
          ranks = {}, subdivisions = {},
        }
        local rseen = {}
        for _, r in ipairs(d.ranks or {}) do
          local rid = slug(r.id ~= '' and r.id or r.label)
          if rid ~= '' and not rseen[rid] then
            rseen[rid] = true
            dept.ranks[#dept.ranks + 1] = { id = rid, label = tostring(r.label or rid):sub(1, 40),
              ace = (r.ace ~= nil and r.ace ~= '') and tostring(r.ace):sub(1, 64) or nil }
          end
        end
        if #dept.ranks == 0 then  -- a dept must have at least one rank to be joinable
          dept.ranks[1] = { id = 'patrol', label = 'Patrol', ace = 'flrp.dept.' .. id }
        end
        local sseen = {}
        for _, s in ipairs(d.subdivisions or {}) do
          local sid = slug(s.id ~= '' and s.id or s.label)
          if sid ~= '' and not sseen[sid] then
            sseen[sid] = true
            dept.subdivisions[#dept.subdivisions + 1] = { id = sid, label = tostring(s.label or sid):sub(1, 40),
              blip = (s.blip ~= nil and s.blip ~= '') and tonumber(s.blip) or nil,
              colour = (s.colour ~= nil and s.colour ~= '') and tostring(s.colour):sub(1, 9) or nil,
              ace = (s.ace ~= nil and s.ace ~= '') and tostring(s.ace):sub(1, 64) or nil }
          end
        end
        out[#out + 1] = dept
      end
    end
  end
  return out
end

local function loadConfig()
  local ok, err = pcall(function()
    local row = FLRP.DB.Single('SELECT `json` FROM `flrp_duty_config` WHERE `id`=1')
    if row and row.json then
      local decoded = json.decode(row.json)
      local clean = sanitizeDepartments(decoded)
      if clean and #clean > 0 then
        CFG.Departments = clean
        print(('[flrp_onduty] loaded %d department(s) from DB config'):format(#clean))
        return
      end
    end
    -- no/blank/invalid row: seed the DB from config.lua so the editor has data
    FLRP.DB.Query('REPLACE INTO `flrp_duty_config` (`id`,`json`,`updated_by`,`updated_at`) VALUES (1,?,?,?)',
      { json.encode(DEFAULT_DEPARTMENTS), 'seed', os.time() })
    print('[flrp_onduty] seeded DB config from config.lua defaults')
  end)
  if not ok then
    print('[flrp_onduty] config load failed, using config.lua defaults: ' .. tostring(err))
    CFG.Departments = DEFAULT_DEPARTMENTS
  end
end

local function saveConfig(depts, byName)
  local clean = sanitizeDepartments(depts)
  if not clean then return false, 'Invalid config payload.' end
  if #clean == 0 then return false, 'You must keep at least one department.' end
  local okEnc, encoded = pcall(json.encode, clean)
  if not okEnc or not encoded then return false, 'Could not encode config.' end
  FLRP.DB.Query('REPLACE INTO `flrp_duty_config` (`id`,`json`,`updated_by`,`updated_at`) VALUES (1,?,?,?)',
    { encoded, tostring(byName or 'staff'):sub(1, 100), os.time() })
  CFG.Departments = clean                                   -- hot-apply
  TriggerClientEvent('flrp_onduty:changed', -1)             -- refresh any open menus
  return true
end

-- ---- config editor handlers (Ownership) ---------------------------------
local function canConfig(src) return IsPlayerAceAllowed(src, CFG.ConfigAce) end

function H.configGet(src)
  if not canConfig(src) then return { ok = false, error = 'Only Ownership can edit the duty config.' } end
  return { ok = true, departments = CFG.Departments, loadouts = CFG.Loadouts and (function()
    local names = {}; for k in pairs(CFG.Loadouts) do names[#names + 1] = k end; table.sort(names); return names
  end)() or {} }
end

function H.configSave(src, p)
  if not canConfig(src) then return { ok = false, error = 'Only Ownership can edit the duty config.' } end
  local ok, err = saveConfig(p.departments, GetPlayerName(src))
  if not ok then return { ok = false, error = err } end
  pcall(function() exports.flrp_logs:Send('menu', { player = src, title = 'DUTY CONFIG',
    description = ('%s updated the duty departments config'):format(GetPlayerName(src) or src) }) end)
  return { ok = true, departments = CFG.Departments }
end

-- ---- boot ----------------------------------------------------------------
CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  local ok, err = pcall(ensureTables)
  if not ok then print('[flrp_onduty] table setup failed: ' .. tostring(err)) end
  loadConfig()
  ready = true
  print(('[flrp_onduty] ready — %d department(s), /%s or %s'):format(#CFG.Departments, CFG.Command, CFG.Key))
end)
