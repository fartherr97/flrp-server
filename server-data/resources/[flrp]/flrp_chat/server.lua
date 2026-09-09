-- ==========================================================================
-- FLRP :: flrp_chat/server.lua
-- ==========================================================================
-- 1. Recolors normal chat display names by the sender's highest staff tier
--    (Discord role colors, from config.lua).
-- 1b. /ooc /gooc (out-of-character, local/global) and /me /gme (emotes).
--    Global lines are relayed to Discord through flrp_chatbridge.
-- 2. Adds ACE-gated channels: /sc (staff), /ac (admin), /dc (director). Each
--    message is prefixed "(LABEL) Name" in the channel color and delivered
--    ONLY to players who hold that channel's ACE.
-- Renders via the base `chat` resource's `chat:addMessage` client event.
-- ==========================================================================

-- The sender's colour + tier key, or nil for non-staff.
local function tierOf(src)
  for _, t in ipairs(FLRP_CHAT.Tiers) do
    if IsPlayerAceAllowed(src, t.ace) then return t.key end
  end
  return nil
end

-- ---- 1. Colored names on normal messages ---------------------------------
-- Base `chat` fires `chatMessage` then broadcasts only if not cancelled. We
-- cancel and re-broadcast with the tier color so staff names are tinted.
AddEventHandler('chatMessage', function(src, name, msg)
  if type(src) ~= 'number' or src <= 0 then return end

  -- Slur filter FIRST: block the base broadcast AND our re-broadcast, then let
  -- flrp_chatfilter kick + log. The message never reaches anyone's chat box.
  local blocked = false
  pcall(function() blocked = exports.flrp_chatfilter:Scan(src, msg) end)
  if blocked then CancelEvent(); return end

  local key = tierOf(src)
  local color = (key and FLRP_CHAT.NameColors[key]) or FLRP_CHAT.NameColors.default
  CancelEvent()
  TriggerClientEvent('chat:addMessage', -1, {
    color = color,
    multiline = true,
    args = { name, msg },
  })
  pcall(function() exports.flrp_logs:Send('chat', { player = src, description = msg }) end)
  pcall(function() exports.flrp_chatbridge:Relay(src, name, msg, 'chat') end)   -- -> Discord #ingame-chat
end)

-- ---- 1b. /ooc /gooc /me /gme ---------------------------------------------
local RP = FLRP_CHAT.RP

local function pname(src) return GetPlayerName(src) or ('Player ' .. src) end

-- Server ids within `radius` metres of `src` (always includes `src`).
local function nearby(src, radius)
  local out = { src }
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return out end
  local origin = GetEntityCoords(ped)
  for _, pid in ipairs(GetPlayers()) do
    local s = tonumber(pid)
    if s and s ~= src then
      local p = GetPlayerPed(s)
      if p and p ~= 0 and #(GetEntityCoords(p) - origin) <= radius then out[#out + 1] = s end
    end
  end
  return out
end

local function usage(src, cmd, what)
  TriggerClientEvent('chat:addMessage', src, { color = { 120, 180, 240 }, args = { 'SYSTEM', ('usage: /%s <%s>'):format(cmd, what) } })
end

-- Shared guts: validate, filter, build the line, deliver, log, relay.
local function rpCommand(cmd, opts)
  RegisterCommand(cmd, function(src, args)
    if type(src) ~= 'number' or src <= 0 then return end
    local message = table.concat(args, ' ')
    message = message:gsub('^%s+', ''):gsub('%s+$', '')
    if message == '' then return usage(src, cmd, opts.what) end
    if #message > 256 then message = message:sub(1, 256) end
    local blocked = false
    pcall(function() blocked = exports.flrp_chatfilter:Scan(src, message) end)
    if blocked then return end
    local name = pname(src)
    local line = { color = opts.color, multiline = true, args = opts.args(name, message) }
    if opts.radius then
      for _, pid in ipairs(nearby(src, opts.radius)) do TriggerClientEvent('chat:addMessage', pid, line) end
    else
      TriggerClientEvent('chat:addMessage', -1, line)
    end
    pcall(function() exports.flrp_logs:Send('chat', { player = src, description = ('/%s %s'):format(cmd, message) }) end)
    if opts.relay then pcall(function() exports.flrp_chatbridge:Relay(src, name, message, opts.relay) end) end
  end, false)
  TriggerEvent('chat:addSuggestion', '/' .. cmd, opts.help, { { name = opts.what, help = opts.help } })
end

rpCommand('ooc',  { what = 'message', help = 'Local out-of-character chat (nearby players)', color = RP.Colors.ooc,  radius = RP.OOCRadius,
  args = function(name, msg) return { ('OOC | %s'):format(name), msg } end })
rpCommand('gooc', { what = 'message', help = 'Global out-of-character chat (everyone)', color = RP.Colors.gooc, relay = 'gooc',
  args = function(name, msg) return { ('GOOC | %s'):format(name), msg } end })
rpCommand('me',   { what = 'action', help = 'Local emote: * Name does something (nearby players)', color = RP.Colors.me, radius = RP.MeRadius,
  args = function(name, msg) return { ('* %s %s'):format(name, msg) } end })
rpCommand('gme',  { what = 'action', help = 'Global emote: * Name does something (everyone)', color = RP.Colors.gme, relay = 'gme',
  args = function(name, msg) return { ('* %s %s'):format(name, msg) } end })

-- ---- 2. Gated channels ----------------------------------------------------
-- May this player use / receive a channel? (its ACE, or an optional bypass ACE)
local function canUse(pid, ch)
  return IsPlayerAceAllowed(pid, ch.ace) or (ch.bypass and IsPlayerAceAllowed(pid, ch.bypass))
end

local function sendChannel(ch, src, message)
  local name = GetPlayerName(src) or ('Player ' .. src)
  local line = {
    color = ch.color,
    multiline = true,
    args = { ('(%s) %s'):format(ch.label, name), message },
  }
  -- Deliver to every online player who holds the channel ACE (incl. sender).
  for _, pid in ipairs(GetPlayers()) do
    pid = tonumber(pid)
    if pid and canUse(pid, ch) then
      TriggerClientEvent('chat:addMessage', pid, line)
    end
  end
  -- Mirror to the server console for logging.
  print(('[flrp_chat] (%s) %s: %s'):format(ch.label, name, message))
end

for cmd, ch in pairs(FLRP_CHAT.Channels) do
  RegisterCommand(cmd, function(src, args)
    if type(src) ~= 'number' or src <= 0 then return end -- console can't be in a staff channel
    if not canUse(src, ch) then
      TriggerClientEvent('chat:addMessage', src, {
        color = { 200, 60, 60 },
        args = { 'SYSTEM', ('You do not have access to %s.'):format(ch.label) },
      })
      return
    end
    local message = table.concat(args, ' ')
    if message == '' then
      TriggerClientEvent('chat:addMessage', src, {
        color = ch.color,
        args = { ('(%s)'):format(ch.label), ('usage: /%s <message>'):format(cmd) },
      })
      return
    end
    sendChannel(ch, src, message)
    pcall(function()
      exports.flrp_logs:Send('staffchat', {
        player = src,
        title = 'COMMAND RAN',
        description = ('/%s %s'):format(cmd, message),
      })
    end)
  end, false) -- unrestricted: we enforce access with the ACE check above

  -- Autocomplete hint in the chat box.
  TriggerClientEvent('chat:addSuggestion', -1, '/' .. cmd, ch.label .. ' (' .. ch.ace .. ')', {
    { name = 'message', help = 'what to say' },
  })
end

-- ---- /clearchat (staff): wipe the chat box for everyone -------------------
RegisterCommand('clearchat', function(src)
  if type(src) == 'number' and src > 0 and not IsPlayerAceAllowed(src, 'flrp.staff.moderate') then
    TriggerClientEvent('chat:addMessage', src, { color = { 200, 60, 60 }, args = { 'SYSTEM', 'You do not have access to /clearchat.' } })
    return
  end
  TriggerClientEvent('chat:clear', -1)
  TriggerClientEvent('chat:addMessage', -1, { color = { 120, 180, 240 }, args = { 'SYSTEM', 'Chat was cleared by staff.' } })
  local who = (type(src) == 'number' and src > 0) and (GetPlayerName(src) or ('Player ' .. src)) or 'Console'
  pcall(function()
    exports.flrp_logs:Send('staffchat', { title = 'CHAT CLEARED',
      description = ('**%s** cleared the in-game chat.'):format(who) })
  end)
end, false)
TriggerEvent('chat:addSuggestion', '/clearchat', 'Staff: clear the in-game chat for everyone')
