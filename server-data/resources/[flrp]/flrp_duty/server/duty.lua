-- ==========================================================================
-- FLRP :: flrp_duty/server/duty.lua — nex-duty adapter
-- ==========================================================================
-- Reads the live on-duty roster from flrp_onduty's `flrp_duty_members` table
-- and maps the entity -> FLRP department. Read-only: flrp_onduty owns toggling
-- duty (its /duty menu). We only report which FLRP department (if any) a player
-- is currently on duty for, so flrp_economy can pay department wages.
-- ==========================================================================

FLRPD = FLRPD or {}
FLRPD.State = { cache = {} } -- source -> { department, onDuty, expires }

-- Resolve the nex-duty entity -> FLRP department map from convars (falling back
-- to defaults in shared/config.lua). Built once, refreshable via command.
FLRPD.entityMap = nil

function FLRPD.BuildEntityMap()
  local map = {}
  for entity, dept in pairs(FLRPD.Config.DefaultEntityMap) do
    -- convar override, e.g. flrp_duty_entity_bso
    local convar = ('flrp_duty_entity_%s'):format(string.lower(dept))
    local override = GetConvar(convar, '')
    local id = (override ~= '' and override) or entity
    map[string.lower(id)] = string.upper(dept)
  end
  FLRPD.entityMap = map
  return map
end

local function entityToDepartment(entity)
  if not entity then return nil end
  local map = FLRPD.entityMap or FLRPD.BuildEntityMap()
  return map[string.lower(entity)]
end

-- Whether the duty registry table exists yet (flrp_onduty creates it on boot).
-- Only a TRUE result is cached: if the table is missing we re-check on the
-- next call, so creating it later (importing nex-duty's database.sql) is picked
-- up live instead of being stuck at "missing" until a resource restart.
local dutyTableReady = false
local warnedMissing = false
local function dutyTableExists()
  if dutyTableReady then return true end
  if not FLRP.DB.IsReady() then return false end
  local ok, row = pcall(function()
    return FLRP.DB.Scalar([[
      SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE() AND table_name = 'flrp_duty_members'
    ]])
  end)
  local exists = ok and (tonumber(row) or 0) > 0
  if exists then
    dutyTableReady = true
  elseif not warnedMissing then
    warnedMissing = true
    FLRP.Logger.Warn('duty', '`flrp_duty_members` not found yet; duty = civilian until flrp_onduty has started')
  end
  return exists
end

-- Fetch the player's current department from nex-duty. Returns { department, onDuty }.
local function fetchDuty(source)
  local rec = exports.flrp_core:GetPlayer(source)
  if not rec or not rec.license then return { department = nil, onDuty = false } end
  if not dutyTableExists() then return { department = nil, onDuty = false } end

  -- nex-duty may store the license with or without the "license:" prefix, and
  -- a player may have multiple duty rows (dual duty). Fetch all their rows and
  -- pick the first that maps to a FLRP department.
  local rows = FLRP.DB.Query([[
    SELECT `entity` FROM `flrp_duty_members`
    WHERE `license` = ? OR `license` = CONCAT('license:', ?) OR `discord` = ? OR `discord` = CONCAT('discord:', ?)
  ]], { rec.license, rec.license, rec.discordId or '', rec.discordId or '' }) or {}

  for _, row in ipairs(rows) do
    local dept = entityToDepartment(row.entity)
    if dept then return { department = dept, onDuty = true } end
  end
  return { department = nil, onDuty = false }
end

-- Cached duty getter.
function FLRPD.Get(source)
  source = tonumber(source)
  if not source then return { department = nil, onDuty = false } end
  local c = FLRPD.State.cache[source]
  local now = os.time()
  if c and c.expires > now then
    return { department = c.department, onDuty = c.onDuty }
  end
  local d = fetchDuty(source)
  FLRPD.State.cache[source] = {
    department = d.department, onDuty = d.onDuty,
    expires = now + (FLRPD.Config.CacheTtlSeconds or 15),
  }
  return d
end

function FLRPD.Remove(source)
  FLRPD.State.cache[tonumber(source)] = nil
end

function FLRPD.Invalidate(source)
  if source then FLRPD.State.cache[tonumber(source)] = nil
  else FLRPD.State.cache = {} end
end

-- Full live on-duty roster straight from flrp_onduty's `flrp_duty_members`
-- table — the source of truth flrp_onduty writes to. Used by the HUD counter, the
-- Discord status embed and the LEO blips, so none of them have to guess at
-- nex-duty's (escrowed) export API.
--
-- Rows are joined to CONNECTED players by license so each entry carries the
-- live server id + in-game name. nex-duty stores the license as
-- "license:<hex>"; we normalise both sides to the bare hex before matching.
-- Returns an array of:
--   { src, online, name, license, entity, department, callsign }
-- `department` is the FLRP dept (BSO/FHP/MPD) or nil for a non-FLRP entity
-- (e.g. nex-duty's "staff" dual-duty entity).
function FLRPD.GetRoster()
  if not FLRP.DB.IsReady() or not dutyTableExists() then return {} end
  local rows = FLRP.DB.Query('SELECT * FROM `flrp_duty_members`') or {}
  if #rows == 0 then return {} end

  -- bare license hex -> connected server id
  local srcByLicense = {}
  for _, pid in ipairs(GetPlayers()) do
    local src = tonumber(pid)
    if src then
      for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then srcByLicense[id:sub(9)] = src end
      end
    end
  end

  local roster = {}
  for _, row in ipairs(rows) do
    local lic = (tostring(row.license or ''):gsub('^license:', ''))
    local src = srcByLicense[lic]
    roster[#roster + 1] = {
      src        = src,
      online     = src ~= nil,
      name       = src and GetPlayerName(src) or nil,
      license    = lic,
      entity     = row.entity and string.lower(tostring(row.entity)) or nil,
      department = entityToDepartment(row.entity),
      callsign   = row.callsign,   -- present when nex-duty require_callsign is on
    }
  end
  return roster
end
