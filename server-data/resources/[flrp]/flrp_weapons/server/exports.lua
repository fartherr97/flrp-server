-- ==========================================================================
-- FLRP :: flrp_weapons/server/exports.lua — public API
-- ==========================================================================
--   exports.flrp_weapons:GetWeapon(weaponName)          -> weapon|nil
--   exports.flrp_weapons:GetStoreCatalog()              -> [{...}]  (display-safe)
--   exports.flrp_weapons:GetAuthoritativePrice(name)    -> cents|nil (server truth)
--   exports.flrp_weapons:IsGunstoreAvailable(name)      -> bool
--   exports.flrp_weapons:IsVMenuSpawnable(name)         -> bool
--   exports.flrp_weapons:OwnsWeapon(source, name)       -> bool
--   exports.flrp_weapons:GetOwnedWeapons(source)        -> [name...]
--   exports.flrp_weapons:RecordOwnership(source, name, via, txId) -> ok
--   exports.flrp_weapons:ReloadRegistry()               -> bool
-- ==========================================================================

function GetWeapon(weaponName) return FLRPW.Registry.Get(weaponName) end
function GetStoreCatalog() return FLRPW.Registry.StoreCatalog() end

function GetAuthoritativePrice(weaponName)
  local w = FLRPW.Registry.Get(weaponName)
  if not w or not w.enabled then return nil end
  return w.priceCents
end

function IsGunstoreAvailable(weaponName)
  local w = FLRPW.Registry.Get(weaponName)
  return w ~= nil and w.enabled and w.gunstoreAvailable
end

function IsVMenuSpawnable(weaponName)
  local w = FLRPW.Registry.Get(weaponName)
  return w ~= nil and w.enabled and w.vmenuSpawnable
end

function OwnsWeapon(source, weaponName) return FLRPW.Ownership.Owns(source, weaponName) end
function GetOwnedWeapons(source) return FLRPW.Ownership.List(source) end

-- Record ownership by SOURCE (resolves players.id). Also pushes the weapon to
-- the client so it is applied immediately.
function RecordOwnership(source, weaponName, via, transactionId)
  local playerId = exports.flrp_core:GetPlayerId(source)
  if not playerId then return false, 'no_player' end
  local ok, err = FLRPW.Ownership.Record(playerId, weaponName, via, transactionId, source)
  if ok then
    TriggerClientEvent('flrp_weapons:grant', source, FLRPW.Registry.Normalize(weaponName))
  end
  return ok, err
end

function ReloadRegistry() return FLRPW.Registry.Load() end
