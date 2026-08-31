-- ==========================================================================
-- FLRP :: flrp_economy/server/exports.lua — public API
-- ==========================================================================
--   exports.flrp_economy:GetBalance(source)            -> cents
--   exports.flrp_economy:CanAfford(source, cents)      -> bool
--   exports.flrp_economy:Credit(source, cents, type, ref, meta, idem) -> ok, bal, txId
--   exports.flrp_economy:Debit(source, cents, type, ref, meta, idem)  -> ok, bal|err
--   exports.flrp_economy:AdminAdjust(source, signedCents, reason, actor, idem) -> ok, bal
--   exports.flrp_economy:GetTransactions(source, limit)-> rows
--   exports.flrp_economy:IsActive(source)              -> bool
--   exports.flrp_economy:GetActiveSeconds(source)      -> seconds
--
-- Callers pass SOURCE (server id); we resolve to players.id internally so
-- other resources never juggle DB ids. All amounts are integer CENTS.
-- ==========================================================================

local function pid(source)
  return exports.flrp_core:GetPlayerId(source)
end

function GetBalance(source)
  local id = pid(source); if not id then return 0 end
  return FLRPE.Wallet.GetBalance(id)
end

function CanAfford(source, cents)
  return GetBalance(source) >= (math.floor(tonumber(cents) or 0))
end

function Credit(source, cents, txType, reference, metadata, idempotencyKey)
  local id = pid(source); if not id then return false, 'no_player' end
  return FLRPE.Wallet.Credit(id, cents, txType, reference, metadata, idempotencyKey)
end

function Debit(source, cents, txType, reference, metadata, idempotencyKey)
  local id = pid(source); if not id then return false, 'no_player' end
  return FLRPE.Wallet.Debit(id, cents, txType, reference, metadata, idempotencyKey)
end

function AdminAdjust(source, signedCents, reason, actorIdentifier, idempotencyKey)
  local id = pid(source); if not id then return false, 'no_player' end
  return FLRPE.Wallet.AdminAdjust(id, signedCents, reason, actorIdentifier, idempotencyKey)
end

function GetTransactions(source, limit)
  local id = pid(source); if not id then return {} end
  return FLRPE.Wallet.GetTransactions(id, limit)
end

function IsActive(source) return FLRPE.Activity.IsActive(tonumber(source)) end
function GetActiveSeconds(source) return FLRPE.Activity.GetActiveSeconds(tonumber(source)) end
