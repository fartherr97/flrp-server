-- ==========================================================================
-- FLRP :: flrp_access/server/tempkick.lua — "kick = temporary lockout"
-- ==========================================================================
-- When a player is kicked by ANY method, lock their identifiers so they can't
-- reconnect for a cooldown window (default 30 min). Kicks are caught three
-- ways so nothing slips through:
--   1. txAdmin's `txAdmin:events:playerKicked` server event (txAdmin kicks).
--   2. A reason-based catch-all on `playerDropped` — covers the slur filter
--      (its drop reason contains "Kicked:") and other admin menus.
--   3. `exports.flrp_access:TempKick(src, reason, minutes)` for FLRP scripts
--      that want to lock someone explicitly.
--
-- NEVER locks on a SERVER RESTART / SHUTDOWN. A restart drops everyone at once;
-- those are not kicks. We suppress them three ways:
--   * a `shuttingDown` flag set by txAdmin scheduled-restart / shutdown events
--     and by this resource stopping;
--   * restart/shutdown/infra wording in the drop reason (isRestartReason);
--   * a bypass ACE (flrp.tempkick.bypass) for trusted accounts, plus a
--     one-shot clean-kick path (flrp_kick / exports:KickBypass).
--
-- The lock is keyed on the player's STABLE identifiers (license/discord/etc.,
-- NOT ip — so a roommate isn't caught) and persisted to resource KVP, so it
-- survives a resource or server restart. The connection gate (main.lua) reads
-- FLRPA.TempKick.Remaining(src) and denies with the time left.
--
-- Toggle / tune with convars (secrets.cfg):
--   set flrp_tempkick_enabled "true"     -- master switch
--   set flrp_tempkick_minutes "30"       -- cooldown length
-- Console / staff commands:
--   flrp_tempkick_clear [all|<id-substring>]   -- unlock everyone / a match
--   flrp_kick <id> [reason...]                 -- kick WITHOUT the lockout
-- ==========================================================================

FLRPA = FLRPA or {}
FLRPA.TempKick = {}

local KVP_KEY = 'flrp_access:tempkick'
local BYPASS_ACE = 'flrp.tempkick.bypass'   -- trusted accts never get locked
local KICK_ACE   = 'flrp.staff.kick'        -- may use /flrp_kick in-game

-- Identifier types we lock on: stable and player-specific. `ip` is deliberately
-- excluded so household/shared-connection players aren't caught by each other.
local LOCK_TYPES = { license = true, license2 = true, discord = true, steam = true, xbl = true, live = true, fivem = true }

local store = {}        -- ["type:value"] = expiryEpoch
local kicked = {}       -- [src] = true, set by explicit kick signals
local bypassSrc = {}    -- [src] = true, one-shot clean-kick marker
local shuttingDown = false   -- true once a server restart/shutdown is in flight

local function nowT() return os.time() end
local function enabled() return GetConvar('flrp_tempkick_enabled', 'true') ~= 'false' end
local function minutes() local m = GetConvarInt('flrp_tempkick_minutes', 30); return (m and m > 0) and m or 30 end

-- ---- persistence ---------------------------------------------------------
local function save() pcall(function() SetResourceKvp(KVP_KEY, json.encode(store)) end) end

local function load()
  local raw = GetResourceKvpString(KVP_KEY)
  if raw and raw ~= '' then
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' then store = t end
  end
end

local function prune()
  local n, changed = nowT(), false
  for k, exp in pairs(store) do
    if type(exp) ~= 'number' or exp <= n then store[k] = nil; changed = true end
  end
  if changed then save() end
end

-- ---- identifiers / bypass ------------------------------------------------
-- The lockable identifiers for a (still-connected or connecting) source.
local function lockIds(src)
  local ids = {}
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    local t = id:match('^(%w+):')
    if t and LOCK_TYPES[t] then ids[#ids + 1] = id end
  end
  return ids
end

-- Trusted account (bot / high staff): never locked, never gated.
local function hasBypass(src)
  if not src then return false end
  if bypassSrc[src] then return true end
  local ok, allowed = pcall(IsPlayerAceAllowed, src, BYPASS_ACE)
  return ok and allowed == true
end

-- ---- restart / shutdown detection ----------------------------------------
-- Wording that means a server restart / shutdown / infra drop, NOT an admin
-- kick. A restart drops EVERYONE, so none of these may ever lock an account.
local function isRestartReason(reason)
  local low = tostring(reason or ''):lower()
  if low == '' then return false end
  return low:find('restart', 1, true) ~= nil
      or low:find('shutting down', 1, true) ~= nil
      or low:find('shutdown', 1, true) ~= nil
      or low:find('reboot', 1, true) ~= nil
      or low:find('server is', 1, true) ~= nil
      or low:find('server closed', 1, true) ~= nil
      or low:find('server stopp', 1, true) ~= nil   -- stopping / stopped
      or low:find('scheduled', 1, true) ~= nil
      or low:find('heartbeat', 1, true) ~= nil
      or low:find('server shutting', 1, true) ~= nil
      or low:find('maintenance', 1, true) ~= nil
end

-- Does a drop `reason` look like a kick/ban rather than a normal disconnect?
-- Player "Quit:" messages are player-controlled, so those are never treated
-- as kicks; restart/shutdown wording is excluded; and we no longer treat a
-- bare "[txadmin]" tag as a kick (txAdmin RESTART drops carry that tag too —
-- real txAdmin kicks arrive via txAdmin:events:playerKicked below).
local function reasonIsKick(reason)
  reason = tostring(reason or '')
  if reason == '' then return false end
  if reason:match('^Quit') or reason:match('^Disconnected') or reason:match('^Exiting')
     or reason:match('^Entering') or reason:match('^Timed?%s*out') or reason:match('^Server') then
    return false
  end
  if isRestartReason(reason) then return false end
  local low = reason:lower()
  return low:find('kick', 1, true) ~= nil
      or low:find('banned', 1, true) ~= nil
end

-- ---- public API ----------------------------------------------------------
-- Lock `src`'s identifiers for `mins` minutes. Safe to call while they're
-- still connected (read their ids before they fully drop). No-ops during a
-- restart/shutdown, for restart-shaped reasons, and for bypass accounts.
function FLRPA.TempKick.Add(src, mins, reason)
  if not enabled() then return end
  if shuttingDown then return end
  if isRestartReason(reason) then return end
  if hasBypass(src) then
    if FLRP and FLRP.Logger then
      FLRP.Logger.Info('access', 'temp-kick skipped (bypass account)', { name = GetPlayerName(src), reason = reason })
    end
    return
  end
  mins = tonumber(mins) or minutes()
  local ids = lockIds(src)
  if #ids == 0 then return end
  local exp = nowT() + math.floor(mins * 60)
  for _, id in ipairs(ids) do store[id] = exp end
  save()
  if FLRP and FLRP.Logger then
    FLRP.Logger.Info('access', 'Temp-kick lock added', {
      name = GetPlayerName(src), minutes = mins, reason = reason, ids = #ids })
  end
end

-- Remaining cooldown (seconds) for a connecting/connected source, else 0.
function FLRPA.TempKick.Remaining(src)
  if not enabled() then return 0 end
  if hasBypass(src) then return 0 end
  prune()
  local rem, n = 0, nowT()
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    local exp = store[id]
    if exp and exp > n and (exp - n) > rem then rem = exp - n end
  end
  return rem
end

-- ---- shutdown / restart signals ------------------------------------------
-- txAdmin scheduled restart: once the countdown is short, stop locking — the
-- mass drop that follows is a restart, not a wave of kicks.
AddEventHandler('txAdmin:events:scheduledRestart', function(data)
  local secs = data and tonumber(data.secondsRemaining)
  if (not secs) or secs <= 120 then shuttingDown = true end
end)

-- Server shutdown stops resources; if WE are stopping, we're going down.
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then shuttingDown = true end
end)

-- Some txAdmin builds emit an explicit shutdown event before a restart/stop.
AddEventHandler('txAdmin:events:serverShuttingDown', function() shuttingDown = true end)

-- ---- kick detection ------------------------------------------------------
-- 1. txAdmin kick event — capture immediately (they're still connected here),
--    but ignore restart-driven mass kicks.
AddEventHandler('txAdmin:events:playerKicked', function(data)
  local t = data and tonumber(data.target)
  if not t then return end
  if isRestartReason(data.reason) then return end
  if GetPlayerName(t) then FLRPA.TempKick.Add(t, minutes(), data.reason or 'txAdmin kick') end
  kicked[t] = true   -- belt & suspenders: playerDropped will re-record
end)

-- 2. Catch-all on drop: clean-kick bypass wins; restart never locks; then a
--    flagged kick or a kick-shaped reason locks.
AddEventHandler('playerDropped', function(reason)
  local src = source
  if bypassSrc[src] then bypassSrc[src] = nil; kicked[src] = nil; return end
  if shuttingDown then kicked[src] = nil; return end
  if kicked[src] or reasonIsKick(reason) then
    FLRPA.TempKick.Add(src, minutes(), 'kick: ' .. tostring(reason))
  end
  kicked[src] = nil
end)

-- 3. Explicit export for FLRP scripts: exports.flrp_access:TempKick(src, reason, mins)
exports('TempKick', function(src, reason, mins)
  FLRPA.TempKick.Add(src, mins or minutes(), reason)
  kicked[src] = true
end)

-- ---- bypass kick: kick WITHOUT the cooldown (for the bot / staff) ---------
-- The bot kicks via rcon / txAdmin console (source 0), so `flrp_kick` lets it
-- (or in-game staff with flrp.staff.kick) drop a player cleanly — they leave
-- now but are NOT locked out. Also exposed as exports:KickBypass for scripts.
local function bypassKick(bySrc, target, reason)
  target = tonumber(target)
  if not target or not GetPlayerName(target) then return false, 'no such player' end
  bypassSrc[target] = true
  DropPlayer(target, reason or 'Kicked (no cooldown)')
  if FLRP and FLRP.Logger then
    FLRP.Logger.Info('access', 'bypass kick (no lockout)', { by = bySrc, target = target, reason = reason })
  end
  return true
end

RegisterCommand('flrp_kick', function(src, args)
  if src ~= 0 and not IsPlayerAceAllowed(src, KICK_ACE) then return end
  local target = args[1]
  local reason = table.concat(args, ' ', 2)
  if reason == '' then reason = 'Kicked by staff' end
  local ok, err = bypassKick(src, target, reason)
  if src == 0 then
    print(ok and ('[flrp_access] bypass-kicked ' .. tostring(target) .. ' (no cooldown)')
              or ('[flrp_access] flrp_kick: ' .. tostring(err)))
  end
end, false)   -- ACE-gated internally; console (bot rcon) always allowed

exports('KickBypass', function(src, reason)
  bypassSrc[src] = true
  DropPlayer(src, reason or 'Kicked')
end)

-- ---- admin: clear the store ----------------------------------------------
-- Console (src 0 / rcon — the bot) or in-game staff with flrp.staff.kick.
RegisterCommand('flrp_tempkick_clear', function(src, args)
  if src ~= 0 and not IsPlayerAceAllowed(src, KICK_ACE) then return end
  local q = args and args[1]
  local function say(msg) if src == 0 then print(msg) end end
  if not q or q == 'all' then
    store = {}; save(); say('[flrp_access] temp-kick store cleared')
    return
  end
  local n = 0
  for k in pairs(store) do if k:find(q, 1, true) then store[k] = nil; n = n + 1 end end
  save()
  say(('[flrp_access] cleared %d temp-kick entr%s matching "%s"')
    :format(n, n == 1 and 'y' or 'ies', q))
end, false)

CreateThread(function()
  load(); prune()
  if FLRP and FLRP.Logger then
    FLRP.Logger.Info('access', 'temp-kick ready', { enabled = enabled(), minutes = minutes() })
  end
end)
