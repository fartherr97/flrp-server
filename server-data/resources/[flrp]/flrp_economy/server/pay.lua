-- ==========================================================================
-- FLRP :: flrp_economy/server/pay.lua — role-based pay distribution
-- ==========================================================================
-- Every minute: accrue active time per player; once a player has accumulated
-- one pay interval of ACTIVE time, pay them (hourly / (60/interval)).
--
-- Which rate applies is server-authoritative:
--   * If the player is ON DUTY in a department (BSO/FHP/MPD), use that
--     department's rate (verified via flrp_duty, which itself verifies the
--     player actually holds the department role).
--   * Otherwise use the BEST civilian/certification rate among the roles the
--     player holds (member / cert_civ_1..3).
-- See docs/ECONOMY.md and docs/DEPARTMENTS.md.
-- ==========================================================================

FLRPE = FLRPE or {}
FLRPE.Pay = {}

local CIV_ROLES = { 'cert_civ_3', 'cert_civ_2', 'cert_civ_1', 'member' }

local function payIntervalMinutes()
  return math.max(1, math.floor(
    tonumber(exports.flrp_core:GetConfig('economy.pay_interval_minutes', 15, 'flrp_pay_interval_minutes')) or 15))
end

-- Determine (roleKey, hourlyCents) that applies to a source right now.
function FLRPE.Pay.ResolveRate(source, playerId)
  -- Department duty pay (if flrp_duty present and player on duty).
  local duty = nil
  if exports.flrp_duty then
    local ok, d = pcall(function() return exports.flrp_duty:GetDuty(source) end)
    if ok then duty = d end
  end
  if duty and duty.onDuty and duty.department then
    local key = string.lower(duty.department)
    if key == 'bso' or key == 'fhp' or key == 'mpd' then
      return key, FLRPE.PayRates.HourlyCents(key)
    end
  end

  -- Civilian/cert pay: best rate among held roles.
  local bestKey, bestRate = 'member', FLRPE.PayRates.HourlyCents('member')
  if exports.flrp_permissions then
    for _, key in ipairs(CIV_ROLES) do
      local ok, inGroup = pcall(function() return exports.flrp_permissions:IsInGroup(source, key) end)
      if ok and inGroup then
        local rate = FLRPE.PayRates.HourlyCents(key)
        if rate > bestRate then bestKey, bestRate = key, rate end
      end
    end
  end
  return bestKey, bestRate
end

-- Pay a single player if they have accumulated a full interval of active time.
function FLRPE.Pay.MaybePay(source)
  local rec = exports.flrp_core:GetPlayer(source)
  if not rec then return end
  local playerId = rec.playerId

  local accum = FLRPE.Activity.AccrueTick(source, 60)
  local intervalSeconds = payIntervalMinutes() * 60
  if accum < intervalSeconds then return end

  -- Compute this interval's pay from the applicable hourly rate.
  local roleKey, hourlyCents = FLRPE.Pay.ResolveRate(source, playerId)
  local intervalsPerHour = 60 / payIntervalMinutes()
  local payCents = math.floor(hourlyCents / intervalsPerHour)

  FLRPE.Activity.ResetAccumulator(source, intervalSeconds)

  if payCents <= 0 then return end

  -- Idempotency: one payout per (player, pay-cycle-timestamp bucket).
  local cycleBucket = math.floor(os.time() / intervalSeconds)
  local idem = ('pay:%d:%d'):format(playerId, cycleBucket)

  local ok, newBal = FLRPE.Wallet.Credit(playerId, payCents, 'pay',
    ('role:%s'):format(roleKey), { role = roleKey, hourlyCents = hourlyCents }, idem)

  if ok then
    -- Persist active playtime periodically alongside pay.
    FLRP.DB.Update([[
      UPDATE `players`
      SET `active_playtime_seconds` = `active_playtime_seconds` + ?
      WHERE `id` = ?
    ]], { intervalSeconds, playerId })
    TriggerClientEvent('flrp_economy:paid', source, payCents, newBal, roleKey)
    FLRP.Logger.Debug('economy', 'Paid player', {
      source = source, role = roleKey, payCents = payCents, balance = newBal })
  end
end

-- Master pay loop.
function FLRPE.Pay.StartLoop()
  CreateThread(function()
    while true do
      Wait(60000) -- one minute
      for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local okc = pcall(function() FLRPE.Pay.MaybePay(src) end)
        if not okc then FLRP.Logger.Warn('economy', 'pay tick error', { source = src }) end
      end
    end
  end)
end
