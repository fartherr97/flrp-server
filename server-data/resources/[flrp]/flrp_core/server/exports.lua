-- ==========================================================================
-- FLRP :: flrp_core/server/exports.lua — documented public API
-- ==========================================================================
-- The ONLY supported way for other resources to talk to flrp_core. Keeping the
-- surface small and documented prevents tight coupling. Signatures:
--
--   exports.flrp_core:IsReady()                 -> bool
--   exports.flrp_core:GetPlayer(source)         -> record|nil  (alias GetPlayerBySource)
--   exports.flrp_core:GetPlayerId(source)       -> number|nil  (players.id)
--   exports.flrp_core:GetPlayerByLicense(lic)   -> record|nil
--   exports.flrp_core:GetIdentifiers(source)    -> { type=value }|nil
--   exports.flrp_core:GetDiscordId(source)      -> string|nil
--   exports.flrp_core:GetConfig(key,default,convar) -> value
--   exports.flrp_core:SetConfig(key,value,type,by) -> bool
--   exports.flrp_core:Log(level,category,msg,data)
--   exports.flrp_core:Audit(entry)              -> bool
-- ==========================================================================

function IsReady()
  return FLRP.DB.IsReady() and FLRP.ConfigStore.loaded
end

function GetPlayerBySource(source)
  return FLRP.Cache.GetBySource(source)
end
-- Primary alias
function GetPlayer(source)
  return FLRP.Cache.GetBySource(source)
end

function GetPlayerId(source)
  local rec = FLRP.Cache.GetBySource(source)
  return rec and rec.playerId or nil
end

function GetPlayerByLicense(license)
  return FLRP.Cache.GetByLicense(license)
end

function GetIdentifiers(source)
  local rec = FLRP.Cache.GetBySource(source)
  if rec then return rec.identifiers end
  -- Fall back to a live read if not yet cached.
  if FLRP.Util.IsValidSource(source) then
    return (FLRP.Identity.GetIdentifiers(source))
  end
  return nil
end

function GetDiscordId(source)
  local rec = FLRP.Cache.GetBySource(source)
  if rec then return rec.discordId end
  if FLRP.Util.IsValidSource(source) then
    return FLRP.Identity.GetDiscordId(source)
  end
  return nil
end

function GetConfig(key, default, convarName)
  return FLRP.ConfigStore.Get(key, default, convarName)
end

function SetConfig(key, value, valueType, updatedBy)
  return FLRP.ConfigStore.Set(key, value, valueType, updatedBy)
end

function Log(level, category, message, data)
  FLRP.Logger.Log(level, category, message, data)
end

function Audit(entry)
  return FLRP.Logger.Audit(entry)
end
