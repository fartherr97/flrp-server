-- ==========================================================================
-- FLRP :: flrp_core/server/cache.lua — in-memory player cache
-- ==========================================================================
-- Holds the live FLRP player record for each connected source. Other flrp_*
-- resources read identity/ids from here rather than re-querying the DB. Domain
-- data (permissions, balance, duty) lives in the OWNING resource's own cache;
-- flrp_core only holds identity + shared metadata to avoid coupling.
--
-- Record shape:
--   {
--     source      = <server id>,
--     playerId    = <players.id>,
--     license     = <string>,
--     discordId   = <string|nil>,
--     name        = <string>,
--     identifiers = { type = value, ... },
--     loadedAt    = <os.time>,
--   }
-- ==========================================================================

FLRP = FLRP or {}
FLRP.Cache = { bySource = {}, byPlayerId = {}, byLicense = {} }

function FLRP.Cache.Set(record)
  FLRP.Cache.bySource[record.source] = record
  if record.playerId then FLRP.Cache.byPlayerId[record.playerId] = record end
  if record.license then FLRP.Cache.byLicense[record.license] = record end
end

function FLRP.Cache.GetBySource(source)
  return FLRP.Cache.bySource[tonumber(source)]
end

function FLRP.Cache.GetByPlayerId(playerId)
  return FLRP.Cache.byPlayerId[tonumber(playerId)]
end

function FLRP.Cache.GetByLicense(license)
  return FLRP.Cache.byLicense[license]
end

function FLRP.Cache.Remove(source)
  local rec = FLRP.Cache.bySource[tonumber(source)]
  if rec then
    if rec.playerId then FLRP.Cache.byPlayerId[rec.playerId] = nil end
    if rec.license then FLRP.Cache.byLicense[rec.license] = nil end
  end
  FLRP.Cache.bySource[tonumber(source)] = nil
  return rec
end

function FLRP.Cache.All()
  return FLRP.Cache.bySource
end
