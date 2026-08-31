-- ==========================================================================
-- FLRP :: flrp_weapons/server/ownership.lua — persistent ownership
-- ==========================================================================
-- Tracks which weapons each player owns (owned_weapons). Ownership is granted
-- by gun-store purchases (flrp_gunstores) or admin grants, and re-applied on
-- spawn. The UNIQUE(player_id, weapon_id) constraint makes RecordOwnership
-- idempotent, which (together with the economy idempotency key) prevents
-- double-grants from duplicate purchase requests.
-- ==========================================================================

FLRPW = FLRPW or {}
FLRPW.Ownership = { bySource = {} } -- source -> { [weaponName] = true }

function FLRPW.Ownership.Load(source, playerId)
  local rows = FLRP.DB.Query([[
    SELECT w.`weapon_name` AS weapon_name
    FROM `owned_weapons` ow JOIN `weapons` w ON w.id = ow.weapon_id
    WHERE ow.player_id = ?
  ]], { playerId }) or {}
  local set = {}
  for _, r in ipairs(rows) do set[FLRPW.Registry.Normalize(r.weapon_name)] = true end
  FLRPW.Ownership.bySource[source] = set
  return set
end

function FLRPW.Ownership.Remove(source)
  FLRPW.Ownership.bySource[source] = nil
end

function FLRPW.Ownership.Owns(source, weaponName)
  local set = FLRPW.Ownership.bySource[tonumber(source)]
  return set ~= nil and set[FLRPW.Registry.Normalize(weaponName)] == true
end

function FLRPW.Ownership.List(source)
  local set = FLRPW.Ownership.bySource[tonumber(source)] or {}
  local out = {}
  for name in pairs(set) do out[#out + 1] = name end
  return out
end

-- Record ownership for a playerId. Idempotent. `via` = gunstore|grant|import.
-- Returns ok. Updates the source cache if the player is online.
function FLRPW.Ownership.Record(playerId, weaponName, via, transactionId, source)
  local w = FLRPW.Registry.Get(weaponName)
  if not w then return false, 'unknown_weapon' end
  FLRP.DB.Update([[
    INSERT INTO `owned_weapons` (`player_id`, `weapon_id`, `acquired_via`, `transaction_id`)
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE `acquired_via` = `acquired_via`
  ]], { playerId, w.id, via or 'grant', transactionId })
  if source then
    local set = FLRPW.Ownership.bySource[tonumber(source)]
    if set then set[w.weaponName] = true end
  end
  return true
end
