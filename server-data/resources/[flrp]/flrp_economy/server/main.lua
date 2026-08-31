-- ==========================================================================
-- FLRP :: flrp_economy/server/main.lua — boot + wiring
-- ==========================================================================

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRPE.PayRates.Load()
  FLRPE.Pay.StartLoop()
  FLRP.Logger.Info('economy', 'flrp_economy ready')
end)

-- On player load: init activity tracking + grant starting balance to a truly
-- new player (idempotent, one-time).
AddEventHandler('flrp_core:playerLoaded', function(source, playerId, record)
  FLRPE.Activity.Init(source)

  -- Starting balance: only if the player has never had a transaction.
  local count = FLRP.DB.Scalar('SELECT COUNT(*) FROM `transactions` WHERE `player_id` = ?', { playerId })
  if (count or 0) == 0 then
    -- Authoritative key is DB config `economy.starting_balance_cents` (CENTS),
    -- seeded by migration 008. Convar fallback `flrp_economy_starting_balance`
    -- is in DOLLARS, so it is only used (×100) when the DB key is absent.
    local startCents
    local dbVal = exports.flrp_core:GetConfig('economy.starting_balance_cents', nil)
    if dbVal ~= nil then
      startCents = math.floor(tonumber(dbVal) or 0)
    else
      local dollars = tonumber(GetConvar('flrp_economy_starting_balance', '500')) or 500
      startCents = math.floor(dollars * 100)
    end
    if startCents > 0 then
      FLRPE.Wallet.Credit(playerId, startCents, 'admin_adjust', 'starting_balance',
        { reason = 'new_player' }, ('start:%d'):format(playerId))
      FLRP.Logger.Info('economy', 'Granted starting balance', { playerId = playerId, cents = startCents })
    end
  end
end)

AddEventHandler('flrp_core:playerDropped', function(source, playerId)
  FLRPE.Activity.Remove(source)
end)

-- Activity heartbeat from client (HINT; bounded server-side). Net event.
RegisterNetEvent('flrp_economy:activityPing', function()
  FLRPE.Activity.Heartbeat(tonumber(source))
end)

-- Console: reload pay rates from DB.
RegisterCommand('flrp_reload_pay', function(source)
  if source ~= 0 and not (exports.flrp_permissions and exports.flrp_permissions:HasPermission(source, 'economy.manage')) then
    return
  end
  FLRPE.PayRates.Load()
  FLRP.Logger.Info('economy', 'Pay rates reloaded')
end, false)

-- Console: check a player's balance (debug).
RegisterCommand('flrp_balance', function(source, args)
  if source ~= 0 then return end
  local target = tonumber(args[1])
  if not target then print('usage: flrp_balance <serverId>') return end
  local id = exports.flrp_core:GetPlayerId(target)
  print(('[FLRP] balance src=%s cents=%s'):format(target, id and FLRPE.Wallet.GetBalance(id) or 'n/a'))
end, true)
