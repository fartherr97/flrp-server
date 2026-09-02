-- ==========================================================================
-- FLRP :: flrp_chat/server.lua
-- ==========================================================================
-- 1. Recolors normal chat display names by the sender's highest staff tier
--    (Discord role colors, from config.lua).
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
  local key = tierOf(src)
  local color = (key and FLRP_CHAT.NameColors[key]) or FLRP_CHAT.NameColors.default
  CancelEvent()
  TriggerClientEvent('chat:addMessage', -1, {
    color = color,
    multiline = true,
    args = { name, msg },
  })
  pcall(function() exports.flrp_logs:Send('chat', { player = src, description = msg }) end)
end)

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
