-- ==========================================================================
-- FLRP :: flrp_core/server/config.lua — runtime configuration access
-- ==========================================================================
-- Unified config lookup with a clear precedence:
--   1. DB `configuration` table   (source of truth; editable by FLRP Manager)
--   2. server convar              (config/*.cfg fallback)
--   3. caller-supplied default
-- Values are cached in-memory and refreshed on demand (SetConfig / Reload).
-- ==========================================================================

FLRP = FLRP or {}
FLRP.ConfigStore = { cache = {}, loaded = false }

-- Load all configuration rows from the DB into cache.
function FLRP.ConfigStore.Load()
  if not FLRP.DB.IsReady() then return false end
  local rows = FLRP.DB.Query('SELECT `key`, `value`, `value_type` FROM `configuration`')
  local cache = {}
  for _, row in ipairs(rows or {}) do
    cache[row.key] = FLRP.ConfigStore._coerce(row.value, row.value_type)
  end
  FLRP.ConfigStore.cache = cache
  FLRP.ConfigStore.loaded = true
  return true
end

function FLRP.ConfigStore._coerce(value, vtype)
  if value == nil then return nil end
  if vtype == 'int' then return math.floor(tonumber(value) or 0) end
  if vtype == 'float' then return tonumber(value) or 0.0 end
  if vtype == 'bool' then
    local v = string.lower(tostring(value))
    return v == 'true' or v == '1' or v == 'yes'
  end
  if vtype == 'json' then
    local ok, decoded = pcall(json.decode, value)
    if ok then return decoded end
    return nil
  end
  return value -- string
end

-- Get a config value. `key` is the configuration.key; falls back to convar
-- (if convarName given) then to `default`.
function FLRP.ConfigStore.Get(key, default, convarName)
  local v = FLRP.ConfigStore.cache[key]
  if v ~= nil then return v end
  if convarName then
    local cv = GetConvar(convarName, '__unset__')
    if cv ~= '__unset__' then return cv end
  end
  return default
end

-- Update a config value (in DB + cache). `actor` is recorded for auditing by
-- the caller (this function only persists). Returns true on success.
function FLRP.ConfigStore.Set(key, value, valueType, updatedBy)
  valueType = valueType or 'string'
  local stored = value
  if valueType == 'json' then stored = json.encode(value) else stored = tostring(value) end
  if not FLRP.DB.IsReady() then return false end
  FLRP.DB.Update([[
    INSERT INTO `configuration` (`key`,`value`,`value_type`,`updated_by`)
    VALUES (?,?,?,?)
    ON DUPLICATE KEY UPDATE `value`=VALUES(`value`),
      `value_type`=VALUES(`value_type`), `updated_by`=VALUES(`updated_by`)
  ]], { key, stored, valueType, updatedBy })
  FLRP.ConfigStore.cache[key] = FLRP.ConfigStore._coerce(stored, valueType)
  return true
end
