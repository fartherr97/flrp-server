-- ==========================================================================
-- FLRP :: flrp_core/server/logging.lua — logging + audit
-- ==========================================================================
-- Two surfaces:
--   FLRP.Logger.Log(level, category, message, data)  -> console (structured)
--   FLRP.Logger.Audit({...})                          -> audit_logs table
-- Audit rows are append-only (see 007_audit_config.sql / docs/SECURITY.md).
-- ==========================================================================

FLRP = FLRP or {}
FLRP.Logger = {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }

local function levelValue(l)
  return LEVELS[string.lower(l or 'info')] or 2
end

function FLRP.Logger.Log(level, category, message, data)
  local threshold = levelValue(FLRP.Config and FLRP.Config.LogLevel or 'info')
  if levelValue(level) < threshold then return end
  local prefix = string.format('[FLRP:%s][%s]', string.upper(level or 'INFO'),
    tostring(category or 'core'))
  if data ~= nil then
    local ok, encoded = pcall(json.encode, data)
    print(('%s %s %s'):format(prefix, tostring(message), ok and encoded or ''))
  else
    print(('%s %s'):format(prefix, tostring(message)))
  end
end

-- Convenience wrappers.
function FLRP.Logger.Debug(cat, msg, data) FLRP.Logger.Log('debug', cat, msg, data) end
function FLRP.Logger.Info(cat, msg, data)  FLRP.Logger.Log('info', cat, msg, data) end
function FLRP.Logger.Warn(cat, msg, data)  FLRP.Logger.Log('warn', cat, msg, data) end
function FLRP.Logger.Error(cat, msg, data) FLRP.Logger.Log('error', cat, msg, data) end

-- Write an audit row. Fields:
--   category (required), action (required), actorPlayerId, actorIdentifier,
--   actorDiscordId, targetType, targetId, oldValue, newValue, reason, source
-- old/new values are JSON-encoded automatically.
function FLRP.Logger.Audit(e)
  if not FLRP.DB.IsReady() then
    FLRP.Logger.Warn('audit', 'DB not ready; audit dropped', e)
    return false
  end
  e = e or {}
  local function enc(v)
    if v == nil then return nil end
    if type(v) == 'string' then return v end
    local ok, s = pcall(json.encode, v)
    return ok and s or tostring(v)
  end
  FLRP.DB.Insert([[
    INSERT INTO `audit_logs`
      (`actor_player_id`,`actor_identifier`,`actor_discord_id`,`category`,
       `action`,`target_type`,`target_id`,`old_value`,`new_value`,`reason`,`source`)
    VALUES (?,?,?,?,?,?,?,?,?,?,?)
  ]], {
    e.actorPlayerId, e.actorIdentifier, e.actorDiscordId,
    e.category or 'general', e.action or 'unknown',
    e.targetType, e.targetId, enc(e.oldValue), enc(e.newValue),
    e.reason, e.source or 'server',
  })
  return true
end
