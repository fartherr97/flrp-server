-- ==========================================================================
-- FLRP :: flrp_core/server/player.lua — persistent player record
-- ==========================================================================
-- Upserts the persistent `players` row and its identifiers, then populates the
-- flrp_core cache. Emits lifecycle events other resources subscribe to:
--
--   'flrp_core:playerLoaded'   (source, playerId, record)   -- server event
--   'flrp_core:playerDropped'  (source, playerId)           -- server event
--
-- Other flrp_* resources load their own domain data on 'playerLoaded' and
-- clean up on 'playerDropped'. This is the ONLY coupling point and it is
-- one-directional (core -> others), so there are no dependency cycles.
-- ==========================================================================

FLRP = FLRP or {}
FLRP.Player = {}

-- Upsert players row + identifiers. Returns players.id or nil on failure.
-- `discordId` and `license` must be server-derived (see identity.lua).
function FLRP.Player.Upsert(license, discordId, name, identList)
  if not license then return nil end

  -- Upsert the primary player row keyed on license.
  local playerId = FLRP.DB.Insert([[
    INSERT INTO `players` (`license`, `discord_id`, `name`, `last_seen`)
    VALUES (?, ?, ?, CURRENT_TIMESTAMP)
    ON DUPLICATE KEY UPDATE
      `discord_id` = VALUES(`discord_id`),
      `name`       = VALUES(`name`),
      `last_seen`  = CURRENT_TIMESTAMP,
      `id`         = LAST_INSERT_ID(`id`)
  ]], { license, discordId, name })

  if not playerId or playerId == 0 then
    -- Fallback: fetch id if insert returned 0 (already existed).
    playerId = FLRP.DB.Scalar('SELECT `id` FROM `players` WHERE `license` = ?', { license })
  end
  if not playerId then return nil end

  -- Ensure a balances row exists (starting balance handled by flrp_economy).
  FLRP.DB.Update('INSERT IGNORE INTO `balances` (`player_id`, `balance_cents`) VALUES (?, 0)',
    { playerId })

  -- Persist identifiers (idempotent on (type, identifier)).
  for _, ident in ipairs(identList or {}) do
    FLRP.DB.Update([[
      INSERT INTO `player_identifiers` (`player_id`, `type`, `identifier`, `last_seen`)
      VALUES (?, ?, ?, CURRENT_TIMESTAMP)
      ON DUPLICATE KEY UPDATE `player_id` = VALUES(`player_id`),
        `last_seen` = CURRENT_TIMESTAMP
    ]], { playerId, ident.type, ident.value })
  end

  return playerId
end

-- Load a connected source into the cache + persist. Safe to call once the
-- player has fully connected (after the deferral has allowed them).
function FLRP.Player.Load(source)
  source = tonumber(source)
  if not FLRP.Util.IsValidSource(source) then return nil end
  if not FLRP.DB.IsReady() then
    FLRP.Logger.Warn('player', 'DB not ready; cannot load player', { source = source })
    return nil
  end

  local map, list = FLRP.Identity.GetIdentifiers(source)
  local license = map.license
  local discordId = map.discord
  local name = GetPlayerName(source) or ('player_' .. source)

  if not license then
    FLRP.Logger.Error('player', 'No license for source; refusing to load', { source = source })
    return nil
  end

  local playerId = FLRP.Player.Upsert(license, discordId, name, list)
  if not playerId then
    FLRP.Logger.Error('player', 'Upsert failed', { source = source, license = license })
    return nil
  end

  local record = {
    source = source,
    playerId = playerId,
    license = license,
    discordId = discordId,
    name = name,
    identifiers = map,
    loadedAt = os.time(),
  }
  FLRP.Cache.Set(record)
  FLRP.Logger.Info('player', 'Player loaded', { source = source, playerId = playerId, name = name })

  -- Notify downstream resources.
  TriggerEvent('flrp_core:playerLoaded', source, playerId, record)
  return record
end

function FLRP.Player.Drop(source)
  source = tonumber(source)
  local rec = FLRP.Cache.Remove(source)
  if rec then
    TriggerEvent('flrp_core:playerDropped', source, rec.playerId)
    -- Persist last_seen bump.
    if FLRP.DB.IsReady() then
      FLRP.DB.Update('UPDATE `players` SET `last_seen` = CURRENT_TIMESTAMP WHERE `id` = ?',
        { rec.playerId })
    end
    FLRP.Logger.Info('player', 'Player dropped', { source = source, playerId = rec.playerId })
  end
end
