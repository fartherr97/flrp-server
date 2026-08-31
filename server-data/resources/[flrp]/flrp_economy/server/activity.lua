-- ==========================================================================
-- FLRP :: flrp_economy/server/activity.lua — anti-AFK active playtime
-- ==========================================================================
-- Tracks compensated ("active") playtime separately from raw connected time.
-- A player is ACTIVE for a tick when BOTH hold:
--   * server-side network liveness: GetPlayerLastMsg(source) < afkTimeout
--     (a loading/frozen/AFK client stops sending net messages), AND
--   * a recent client activity heartbeat (control input while spawned).
-- The client heartbeat is only a HINT and is bounded by the server check, so
-- a spoofed heartbeat cannot manufacture pay while genuinely idle.
-- ==========================================================================

FLRPE = FLRPE or {}
FLRPE.Activity = { bySource = {} } -- source -> { lastHeartbeat, accumSeconds, activeTotal, spawnGraceUntil }

local function cfgInt(key, convar, default)
  return math.floor(tonumber(exports.flrp_core:GetConfig(key, default, convar)) or default)
end

function FLRPE.Activity.Init(source)
  FLRPE.Activity.bySource[source] = {
    lastHeartbeat = 0,
    accumSeconds = 0,            -- active seconds counted toward next payout
    activeTotal = 0,             -- active seconds this session (persisted periodically)
    spawnGraceUntil = os.time() + cfgInt('economy.spawn_grace_seconds', 'flrp_active_spawn_grace_seconds', 30),
  }
end

function FLRPE.Activity.Remove(source)
  FLRPE.Activity.bySource[source] = nil
end

function FLRPE.Activity.Heartbeat(source)
  local a = FLRPE.Activity.bySource[source]
  if a then a.lastHeartbeat = os.time() end
end

-- Is the player currently active/compensable?
function FLRPE.Activity.IsActive(source)
  local a = FLRPE.Activity.bySource[source]
  if not a then return false end
  if os.time() < a.spawnGraceUntil then return false end

  local afkTimeout = cfgInt('economy.afk_timeout_seconds', 'flrp_afk_timeout_seconds', 300)

  -- Server-side liveness: ms since last network message from this client.
  local lastMsg = GetPlayerLastMsg(source)
  if lastMsg == nil then return false end
  if lastMsg > (afkTimeout * 1000) then return false end

  -- Client heartbeat freshness (bounded hint): must have heartbeat within the
  -- AFK window. If pay does not require active heartbeat, liveness alone counts.
  local requireActive = exports.flrp_core:GetConfig('economy.pay_requires_active', true, 'flrp_pay_requires_active')
  if requireActive == false or requireActive == 'false' then
    return true
  end
  return (os.time() - a.lastHeartbeat) <= afkTimeout
end

function FLRPE.Activity.GetActiveSeconds(source)
  local a = FLRPE.Activity.bySource[source]
  return a and a.activeTotal or 0
end

-- Called each minute tick by pay.lua; adds active seconds when active.
-- Returns the accumulator (seconds toward next payout) after adding.
function FLRPE.Activity.AccrueTick(source, tickSeconds)
  local a = FLRPE.Activity.bySource[source]
  if not a then return 0 end
  if FLRPE.Activity.IsActive(source) then
    a.accumSeconds = a.accumSeconds + tickSeconds
    a.activeTotal = a.activeTotal + tickSeconds
  end
  return a.accumSeconds
end

function FLRPE.Activity.ResetAccumulator(source, subtractSeconds)
  local a = FLRPE.Activity.bySource[source]
  if a then a.accumSeconds = math.max(0, a.accumSeconds - subtractSeconds) end
end
