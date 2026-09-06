-- ==========================================================================
-- FLRP :: flrp_messages/server.lua — private-message relay, monitor, logging
-- ==========================================================================
-- Session-scoped: history lives in memory and resets on restart. Players are
-- keyed internally by license (stable across reconnects); the client only ever
-- sees an opaque conversation KEY, never a raw identifier. Every action is
-- re-validated server-side.
-- ==========================================================================

local MSG = FLRP_MESSAGES

local function isStaff(src) return IsPlayerAceAllowed(src, MSG.MonitorAce) end
local function pname(src)   return GetPlayerName(src) or ('Player ' .. tostring(src)) end

local function licenseOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'license:' then return id end
  end
  return 'src:' .. tostring(src)   -- fallback so PMs still work without a license
end

local function srcForLicense(lic)
  for _, pid in ipairs(GetPlayers()) do
    pid = tonumber(pid)
    if licenseOf(pid) == lic then return pid end
  end
  return nil
end

-- Opaque, stable client-facing key for a license (licenses stay server-side).
local keyToLic = {}
local function keyFor(lic)
  local k = ('c%08x'):format(GetHashKey(lic) & 0xFFFFFFFF)
  keyToLic[k] = lic
  return k
end

-- ---- history (flat, trimmed) ---------------------------------------------
local history = {}   -- { fromLic, fromName, toLic, toName, text, ts }

local function record(m)
  history[#history + 1] = m
  while #history > MSG.MaxHistory do table.remove(history, 1) end
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function safe(s) return (tostring(s or ''):gsub('@everyone', '@\226\128\139everyone'):gsub('@here', '@\226\128\139here')) end

-- Newest message per peer, for one license.
local function conversationsFor(lic)
  local byPeer, order = {}, {}
  for _, m in ipairs(history) do
    local peer, peerName
    if m.fromLic == lic then peer, peerName = m.toLic, m.toName
    elseif m.toLic == lic then peer, peerName = m.fromLic, m.fromName end
    if peer then
      if not byPeer[peer] then order[#order + 1] = peer end
      byPeer[peer] = { lic = peer, peerName = peerName, lastText = m.text,
                       lastTs = m.ts, fromMe = (m.fromLic == lic) }
    end
  end
  local out = {}
  for _, peer in ipairs(order) do
    local e = byPeer[peer]
    out[#out + 1] = { key = keyFor(peer), peerName = e.peerName, peerId = srcForLicense(peer),
                      lastText = e.lastText, lastTs = e.lastTs, fromMe = e.fromMe }
  end
  table.sort(out, function(a, b) return a.lastTs > b.lastTs end)
  return out
end

local function threadFor(lic, peerLic)
  local out = {}
  for _, m in ipairs(history) do
    if (m.fromLic == lic and m.toLic == peerLic) or (m.fromLic == peerLic and m.toLic == lic) then
      out[#out + 1] = { mine = (m.fromLic == lic), fromName = m.fromName, text = m.text, ts = m.ts }
    end
  end
  return out
end

local function monitorFeed(limit)
  local out, n = {}, #history
  for i = math.max(1, n - (limit or 120) + 1), n do
    local m = history[i]
    out[#out + 1] = { fromName = m.fromName, toName = m.toName, text = m.text, ts = m.ts }
  end
  return out
end

local function onlineList(exceptSrc)
  local out = {}
  for _, pid in ipairs(GetPlayers()) do
    pid = tonumber(pid)
    if pid ~= exceptSrc then out[#out + 1] = { id = pid, name = pname(pid) } end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

-- Client-safe copy of a message (keys, never licenses).
local function clientMsg(m)
  return { fromName = m.fromName, toName = m.toName, text = m.text, ts = m.ts,
           fromKey = keyFor(m.fromLic), toKey = keyFor(m.toLic) }
end

-- ---- delivery -------------------------------------------------------------
local function deliver(m, fromSrc, toSrc)
  local cm = clientMsg(m)
  if toSrc then TriggerClientEvent('flrp_messages:incoming', toSrc, cm) end
  if fromSrc then TriggerClientEvent('flrp_messages:sent', fromSrc, cm) end

  for _, pid in ipairs(GetPlayers()) do
    pid = tonumber(pid)
    if pid ~= fromSrc and pid ~= toSrc and isStaff(pid) then
      TriggerClientEvent('flrp_messages:monitor', pid, { fromName = m.fromName, toName = m.toName, text = m.text, ts = m.ts })
    end
  end

  if MSG.LogWebhook then
    pcall(function()
      exports.flrp_logs:Send('pm', {
        title = 'PRIVATE MESSAGE',
        description = ('**%s** → **%s**\n%s'):format(safe(m.fromName), safe(m.toName), safe(m.text)),
      })
    end)
  end
end

-- targetId is a server id (must be online).
local function doSend(src, targetId, text)
  text = trim(text)
  if text == '' then return false, 'Message is empty.' end
  if #text > MSG.MaxLength then text = text:sub(1, MSG.MaxLength) end
  targetId = tonumber(targetId)
  if not targetId or not GetPlayerName(targetId) then return false, "That player isn't online." end
  if targetId == src then return false, "You can't message yourself." end

  local m = {
    fromLic = licenseOf(src), fromName = pname(src),
    toLic   = licenseOf(targetId), toName = pname(targetId),
    text    = text, ts = os.time(),
  }
  record(m)
  deliver(m, src, targetId)
  return true
end

-- ---- request/response bridge (NUI is client-side; client relays here) -----
local H = {}

function H.open(src)
  local staff = isStaff(src)
  return { ok = true, me = { id = src, name = pname(src) }, isStaff = staff,
           maxLength = MSG.MaxLength, now = os.time(),
           conversations = conversationsFor(licenseOf(src)),
           online = onlineList(src),
           monitor = staff and monitorFeed(120) or nil }
end

function H.thread(src, p)
  local peerLic = p and p.key and keyToLic[p.key]
  if not peerLic then return { ok = false, error = 'Conversation not found.' } end
  local peerId, peerName = srcForLicense(peerLic), nil
  for _, m in ipairs(history) do
    if m.fromLic == peerLic then peerName = m.fromName
    elseif m.toLic == peerLic then peerName = m.toName end
  end
  return { ok = true, peer = { key = p.key, peerName = peerName, peerId = peerId },
           messages = threadFor(licenseOf(src), peerLic) }
end

function H.send(src, p)
  p = p or {}
  local targetId = tonumber(p.toId)
  if not targetId and p.key then
    local lic = keyToLic[p.key]
    targetId = lic and srcForLicense(lic) or nil
    if not targetId then return { ok = false, error = 'They are offline.' } end
  end
  local ok, err = doSend(src, targetId, p.text)
  return { ok = ok, error = err }
end

RegisterNetEvent('flrp_messages:req', function(action, payload, seq)
  local src = source
  local fn = H[action]
  local res = fn and fn(src, payload) or { ok = false, error = 'Unknown action.' }
  TriggerClientEvent('flrp_messages:res', src, seq, res)
end)

-- Quick send from /pm <id> <msg> (no panel).
RegisterNetEvent('flrp_messages:quick', function(targetId, text)
  local src = source
  local ok, err = doSend(src, targetId, text)
  TriggerClientEvent('flrp_notify:toast', src, ok
    and { title = 'Messages', kind = 'ok',    body = ('Sent to [%s].'):format(tonumber(targetId) or '?') }
    or  { title = 'Messages', kind = 'error', body = err or 'Failed.' })
end)
