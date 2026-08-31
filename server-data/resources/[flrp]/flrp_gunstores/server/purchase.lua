-- ==========================================================================
-- FLRP :: flrp_gunstores/server/purchase.lua — secure purchase flow
-- ==========================================================================
-- The authoritative 10-step purchase. NOTHING the client sends is trusted
-- except the identifiers of WHAT they want to buy (weapon name + store id);
-- every decision (eligibility, permission, price, balance) is made server-side.
-- See docs/WEAPONS.md and docs/SECURITY.md.
-- ==========================================================================

FLRPG = FLRPG or {}
FLRPG.Purchase = {}

-- Per-source in-flight lock to reject concurrent double-submits.
local inFlight = {}

-- Distance^2 between a player ped and a coords table.
local function playerNear(source, coords, tolerance)
  local ped = GetPlayerPed(source)
  if not ped or ped == 0 then return false end
  local px, py, pz = table.unpack(GetEntityCoords(ped))
  local dx, dy, dz = px - coords.x, py - coords.y, pz - coords.z
  local dist2 = dx*dx + dy*dy + dz*dz
  return dist2 <= (tolerance * tolerance)
end

-- Main entry. Returns ok, resultTable|errCode.
function FLRPG.Purchase.Attempt(source, weaponName, storeId)
  source = tonumber(source)

  -- Reject re-entrant purchase from the same source.
  if inFlight[source] then return false, 'busy' end
  inFlight[source] = true
  local function done(ok, res) inFlight[source] = nil return ok, res end

  -- (1) validate player
  local rec = exports.flrp_core:GetPlayer(source)
  if not rec then return done(false, 'no_player') end
  local playerId = rec.playerId

  -- proximity: player must be near the claimed store (anti-exploit)
  local store = FLRPG.Config.GetStore(storeId)
  if not store then return done(false, 'bad_store') end
  if not playerNear(source, store.coords, FLRPG.Config.ServerProximityTolerance) then
    FLRP.Logger.Warn('gunstore', 'Purchase rejected: not near store', {
      source = source, storeId = storeId })
    return done(false, 'too_far') end

  -- (2) validate weapon (registry, enabled, gunstore-available)
  weaponName = type(weaponName) == 'string' and string.upper(weaponName) or nil
  if not weaponName then return done(false, 'bad_weapon') end
  if not exports.flrp_weapons:IsGunstoreAvailable(weaponName) then
    return done(false, 'not_available') end
  local weapon = exports.flrp_weapons:GetWeapon(weaponName)
  if not weapon then return done(false, 'not_available') end

  -- (3) validate eligibility (certification requirement)
  if weapon.certRequired and weapon.certRequired ~= '' then
    local hasCert = exports.flrp_permissions:IsInGroup(source, weapon.certRequired)
    if not hasCert then return done(false, 'need_cert') end
  end

  -- (4) validate permission (base purchase perm + any weapon-specific perm)
  if not exports.flrp_permissions:HasPermission(source, 'weapon.gunstore.purchase') then
    return done(false, 'no_permission') end
  if weapon.requiredPermission and weapon.requiredPermission ~= '' then
    if not exports.flrp_permissions:HasPermission(source, weapon.requiredPermission) then
      return done(false, 'no_permission') end
  end

  -- Already owns it? (idempotent, avoid charging twice)
  if exports.flrp_weapons:OwnsWeapon(source, weaponName) then
    return done(false, 'already_owned') end

  -- (5) fetch AUTHORITATIVE price (never trust client price)
  local priceCents = exports.flrp_weapons:GetAuthoritativePrice(weaponName)
  if priceCents == nil then return done(false, 'not_available') end

  -- (6) validate balance
  if not exports.flrp_economy:CanAfford(source, priceCents) then
    return done(false, 'insufficient_funds') end

  -- (7)+(8) atomically deduct + record transaction (idempotent)
  local idem = ('buy:%d:%s:%d'):format(playerId, weaponName, math.floor(os.time() / 5))
  local ok, balOrErr, txId = exports.flrp_economy:Debit(
    source, priceCents, 'purchase', ('weapon:%s'):format(weaponName),
    { store = storeId, weapon = weaponName }, idem)
  if not ok then return done(false, balOrErr or 'debit_failed') end

  -- (9) record ownership (idempotent) + (10) grant weapon to client
  local okOwn, ownErr = exports.flrp_weapons:RecordOwnership(source, weaponName, 'gunstore', txId)
  if not okOwn then
    -- Ownership record failed after charging — refund to stay consistent.
    exports.flrp_economy:Credit(source, priceCents, 'refund',
      ('weapon:%s'):format(weaponName), { reason = 'ownership_failed' },
      ('refund:%s'):format(idem))
    FLRP.Logger.Error('gunstore', 'Ownership failed; refunded', {
      source = source, weapon = weaponName, err = ownErr })
    return done(false, 'ownership_failed')
  end

  FLRP.Logger.Info('gunstore', 'Purchase complete', {
    source = source, weapon = weaponName, priceCents = priceCents, balance = balOrErr })
  FLRP.Logger.Audit({
    actorPlayerId = playerId, actorIdentifier = rec.license, actorDiscordId = rec.discordId,
    category = 'weapons', action = 'purchase', targetType = 'weapon', targetId = weaponName,
    newValue = { priceCents = priceCents, store = storeId }, source = 'server' })

  return done(true, { weapon = weaponName, priceCents = priceCents, balanceCents = balOrErr })
end
