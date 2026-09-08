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
-- The lock is keyed on the player's STABLE identifiers (license/discord/etc.,
-- NOT ip — so a roommate isn't caught) and persisted to resource KVP, so it
-- survives a resource or server restart. The connection gate (main.lua) reads
-- FLRPA.TempKick.Remaining(src) and denies with the time left.
--
-- Toggle / tune with convars (secrets.cfg):
--   set flrp_tempkick_enabled "true"     -- master switch
--   set flrp_tempkick_minutes "30"       -- cooldown length
-- Clear from the server console:  flrp_tempkick_clear [all|<id-substring>]
-- ==========================================================================

FLRPA = FLRPA or {}
FLRPA.TempKick = {}

local KVP_KEY = 'flrp_access:tempkick'

-- Identifier types we lock on: stable and player-specific. `ip` is deliberately
-- excluded so household/shared-connection players aren't caught by each other.
local LOCK_TYPES = { license = true, license2 = true, discord = true, steam = true, xbl = true, live = true, fivem = true }

local store = {}   -- ["type:value"] = expiryEpoch

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

-- ---- identifiers ---------------------------------------------------------
-- The lockable identifiers for a (still-connected or connecting) source.
local function lockIds(src)
  local ids = {}
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    local t = id:match('^(%w+):')
    if t and LOCK_TYPES[t] then ids[#ids + 1] = id end
  end
  return ids
end

-- ---- public API ----------------------------------------------------------
-- Lock `src`'s identifiers for `mins` minutes. Safe to call while they're
-- still connected (read their ids before they fully drop).
function FLRPA.TempKick.Add(src, mins, reason)
  if not enabled() then return end
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
  prune()
  local rem, n = 0, nowT()
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    local exp = store[id]
    if exp and exp > n and (exp - n) > rem then rem = exp - n end
  end
  return rem
end

-- ---- kick detection ------------------------------------------------------
local kicked = {}   -- [src] = true, set by explicit kick signals

-- Does a drop `reason` look like a kick/ban rather than a normal disconnect?
-- Player "Quit:" messages are player-controlled, so those are never treated
-- as kicks; we only match server-generated kick/ban wording.
local function reasonIsKick(reason)
  reason = tostring(reason or '')
  if reason == '' then return false end
  if reason:match('^Quit') or reason:match('^Disconnected') or reason:match('^Exiting')
     or reason:match('^Entering') or reason:match('^Timed?%s*out') or reason:match('^Server') then
    return false
  end
  local low = reason:lower()
  return low:find('kick', 1, true) ~= nil
      or low:find('banned', 1, true) ~= nil
      or low:find('[txadmin]', 1, true) ~= nil
end

-- 1. txAdmin kick event — capture immediately (they're still connected here).
AddEventHandler('txAdmin:events:playerKicked', function(data)
  local t = data and tonumber(data.target)
  if not t then return end
  if GetPlayerName(t) then FLRPA.TempKick.Add(t, minutes(), data.reason or 'txAdmin kick') end
  kicked[t] = true   -- belt & suspenders: playerDropped will re-record
end)

-- 2. Catch-all on drop: flagged kick, or a kick-shaped reason.
AddEventHandler('playerDropped', function(reason)
  local src = source
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

-- ---- admin: clear the store ----------------------------------------------
RegisterCommand('flrp_tempkick_clear', function(src, args)
  if src ~= 0 then return end   -- console / rcon only
  local q = args and args[1]
  if not q or q == 'all' then
    store = {}; save(); print('[flrp_access] temp-kick store cleared')
    return
  end
  local n = 0
  for k in pairs(store) do if k:find(q, 1, true) then store[k] = nil; n = n + 1 end end
  save()
  print(('[flrp_access] cleared %d temp-kick entr%s matching "%s"')
    :format(n, n == 1 and 'y' or 'ies', q))
end, true)

CreateThread(function()
  load(); prune()
  if FLRP and FLRP.Logger then
    FLRP.Logger.Info('access', 'temp-kick ready', { enabled = enabled(), minutes = minutes() })
  end
end)
