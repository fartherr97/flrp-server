-- ==========================================================================
-- FLRP :: flrp_duty/server/duty.lua — nex-duty adapter
-- ==========================================================================
-- Reads the live on-duty roster from nex-duty's `duty_members` table and maps
-- the nex-duty entity -> FLRP department. Read-only: nex-duty owns toggling
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

-- Whether nex-duty's table exists yet (before nex-duty is installed/migrated).
local dutyTableReady = nil
local function dutyTableExists()
  if dutyTableReady ~= nil then return dutyTableReady end
  if not FLRP.DB.IsReady() then return false end
  local ok, row = pcall(function()
    return FLRP.DB.Scalar([[
      SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE() AND table_name = 'duty_members'
    ]])
  end)
  dutyTableReady = ok and (tonumber(row) or 0) > 0
  if not dutyTableReady then
    FLRP.Logger.Warn('duty', 'nex-duty `duty_members` table not found yet; duty = civilian until nex-duty is installed')
  end
  return dutyTableReady
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
    SELECT `entity` FROM `duty_members`
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
