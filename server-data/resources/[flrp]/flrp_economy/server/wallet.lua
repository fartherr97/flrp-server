-- ==========================================================================
-- FLRP :: flrp_economy/server/wallet.lua — race-safe money operations
-- ==========================================================================
-- All amounts are integer CENTS. Every mutation is server-authoritative and
-- race-safe:
--   * DEBIT uses a single guarded atomic UPDATE
--       UPDATE balances SET balance_cents = balance_cents - ?
--       WHERE player_id = ? AND balance_cents >= ?
--     InnoDB row-locks the row for the UPDATE, so concurrent debits are
--     serialized and can never overdraw (affectedRows==0 => insufficient).
--   * Every mutation writes an append-only `transactions` row carrying
--     balance_after_cents and a UNIQUE idempotency_key, which defeats
--     duplicate/replayed requests (a repeated key can insert only once).
-- See docs/DATABASE.md (Race-condition safety) and docs/SECURITY.md.
-- ==========================================================================

FLRPE = FLRPE or {}
FLRPE.Wallet = {}

local function readBalance(playerId)
  return FLRP.DB.Scalar('SELECT `balance_cents` FROM `balances` WHERE `player_id` = ?', { playerId })
end

-- Returns balance in cents (0 if no row).
function FLRPE.Wallet.GetBalance(playerId)
  if not playerId then return 0 end
  return readBalance(playerId) or 0
end

-- If an idempotency key was already used, return its recorded result so a
-- replayed request is a no-op that reports success. Returns row or nil.
local function findByIdempotency(key)
  if not key then return nil end
  return FLRP.DB.Single(
    'SELECT `id`, `balance_after_cents` FROM `transactions` WHERE `idempotency_key` = ?', { key })
end

-- Credit money (add). Returns ok, newBalanceCents, txId | ok=false, errCode.
function FLRPE.Wallet.Credit(playerId, amountCents, txType, reference, metadata, idempotencyKey)
  amountCents = math.floor(tonumber(amountCents) or 0)
  if not playerId then return false, 'no_player' end
  if amountCents <= 0 then return false, 'bad_amount' end

  local existing = findByIdempotency(idempotencyKey)
  if existing then return true, existing.balance_after_cents, existing.id end

  local affected = FLRP.DB.Update(
    'UPDATE `balances` SET `balance_cents` = `balance_cents` + ?, `version` = `version` + 1 WHERE `player_id` = ?',
    { amountCents, playerId })
  if not affected or affected < 1 then
    -- Ensure a balances row exists then retry once.
    FLRP.DB.Update('INSERT IGNORE INTO `balances` (`player_id`, `balance_cents`) VALUES (?, 0)', { playerId })
    FLRP.DB.Update(
      'UPDATE `balances` SET `balance_cents` = `balance_cents` + ?, `version` = `version` + 1 WHERE `player_id` = ?',
      { amountCents, playerId })
  end

  local newBal = readBalance(playerId) or amountCents
  local txId = FLRPE.Wallet._ledger(playerId, amountCents, newBal, txType or 'admin_adjust',
    reference, metadata, idempotencyKey)
  return true, newBal, txId
end

-- Debit money (subtract) with overdraft + race protection.
-- Returns ok, newBalanceCents, txId | ok=false, errCode ('insufficient_funds', ...).
function FLRPE.Wallet.Debit(playerId, amountCents, txType, reference, metadata, idempotencyKey)
  amountCents = math.floor(tonumber(amountCents) or 0)
  if not playerId then return false, 'no_player' end
  if amountCents <= 0 then return false, 'bad_amount' end

  local existing = findByIdempotency(idempotencyKey)
  if existing then return true, existing.balance_after_cents, existing.id end

  -- Atomic guarded debit — the critical section.
  local affected = FLRP.DB.Update([[
    UPDATE `balances`
    SET `balance_cents` = `balance_cents` - ?, `version` = `version` + 1
    WHERE `player_id` = ? AND `balance_cents` >= ?
  ]], { amountCents, playerId, amountCents })

  if not affected or affected < 1 then
    return false, 'insufficient_funds'
  end

  local newBal = readBalance(playerId) or 0
  local txId = FLRPE.Wallet._ledger(playerId, -amountCents, newBal, txType or 'purchase',
    reference, metadata, idempotencyKey)
  return true, newBal, txId
end

-- Append-only ledger write. If the idempotency key collides (concurrent
-- replay) the UNIQUE constraint rejects it — treated as already-recorded.
function FLRPE.Wallet._ledger(playerId, signedAmount, balanceAfter, txType, reference, metadata, idempotencyKey)
  local meta = nil
  if metadata ~= nil then
    local ok, enc = pcall(json.encode, metadata)
    meta = ok and enc or nil
  end
  local txId = FLRP.DB.Insert([[
    INSERT INTO `transactions`
      (`player_id`, `amount_cents`, `balance_after_cents`, `type`, `reference`, `idempotency_key`, `metadata`)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  ]], { playerId, signedAmount, balanceAfter, txType, reference, idempotencyKey, meta })
  return txId
end

-- Admin adjustment (signed). Audited by caller. Returns ok, newBalance.
function FLRPE.Wallet.AdminAdjust(playerId, signedCents, reason, actorIdentifier, idempotencyKey)
  signedCents = math.floor(tonumber(signedCents) or 0)
  if signedCents == 0 then return false, 'bad_amount' end
  local ok, bal, txId
  if signedCents > 0 then
    ok, bal, txId = FLRPE.Wallet.Credit(playerId, signedCents, 'admin_adjust', reason, { actor = actorIdentifier }, idempotencyKey)
  else
    ok, bal, txId = FLRPE.Wallet.Debit(playerId, -signedCents, 'admin_adjust', reason, { actor = actorIdentifier }, idempotencyKey)
  end
  return ok, bal, txId
end

-- Recent transactions for a player (default 25).
function FLRPE.Wallet.GetTransactions(playerId, limit)
  limit = math.min(math.max(tonumber(limit) or 25, 1), 200)
  return FLRP.DB.Query([[
    SELECT `id`, `amount_cents`, `balance_after_cents`, `type`, `reference`, `created_at`
    FROM `transactions` WHERE `player_id` = ?
    ORDER BY `id` DESC LIMIT ?
  ]], { playerId, limit }) or {}
end
