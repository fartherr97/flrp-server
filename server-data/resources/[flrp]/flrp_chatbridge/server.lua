-- ==========================================================================
-- FLRP :: flrp_chatbridge/server.lua — in-game chat <-> Discord channel
-- ==========================================================================
-- Outbound: exports.flrp_chatbridge:Relay(src, name, message, tag) queues a
-- line; a flush thread posts batches to the Discord webhook. Discord markdown
-- and mentions are neutralised so a player can't ping @everyone from the game.
-- Inbound: exports.flrp_chatbridge:FromDiscord(name, message) renders a line in
-- every chatbox as "[Discord] Name: message" (called by flrp_api).
-- ==========================================================================

local C = FLRP_CHATBRIDGE
local queue, queueChars, firstAt = {}, 0, nil

local function webhook()
  local url = GetConvar(C.WebhookConvar, '')
  if url == '' or url == 'REPLACE_ME' then return nil end
  return url
end

-- Escape Discord markdown + mass mentions in player-supplied text.
local function clean(s)
  s = tostring(s or '')
  s = s:gsub('[%*_~`|\\>]', '\\%0')
  s = s:gsub('@everyone', '@\u{200B}everyone'):gsub('@here', '@\u{200B}here')
  s = s:gsub('<@', '<@\u{200B}')          -- user/role mention syntax
  s = s:gsub('[\r\n]+', ' ')
  return s
end

local function fill(fmt, vars)
  return (fmt:gsub('{(%w+)}', function(k) return vars[k] or '' end))
end

local function post(content)
  local url = webhook()
  if not url then return end
  PerformHttpRequest(url, function(status)
    if status ~= 204 and status ~= 200 then
      print(('^3[flrp_chatbridge] webhook HTTP %s^0'):format(tostring(status)))
    end
  end, 'POST', json.encode({
    content = content,
    username = C.Username ~= '' and C.Username or nil,
    avatar_url = C.Avatar ~= '' and C.Avatar or nil,
    allowed_mentions = { parse = {} },   -- never ping anyone from game chat
  }), { ['Content-Type'] = 'application/json' })
end

local function flush()
  if #queue == 0 then return end
  local content = table.concat(queue, '\n')
  queue, queueChars, firstAt = {}, 0, nil
  post(content)
end

local function relay(src, name, message, tag)
  tag = tag or 'chat'
  if not C.Relay[tag] then return false end
  if not webhook() then return false end
  local fmt = C.Format[tag] or C.Format.chat
  local line = fill(fmt, { id = tostring(src), name = clean(name), msg = clean(message) })
  if #line > C.MaxChars then line = line:sub(1, C.MaxChars - 1) .. '…' end
  if queueChars + #line + 1 > C.MaxChars then flush() end
  queue[#queue + 1] = line
  queueChars = queueChars + #line + 1
  firstAt = firstAt or GetGameTimer()
  return true
end
exports('Relay', relay)

CreateThread(function()
  while true do
    Wait(250)
    if firstAt and (GetGameTimer() - firstAt) >= C.FlushMs then flush() end
  end
end)
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then flush() end
end)

-- ---- inbound ---------------------------------------------------------------
local function fromDiscord(name, message)
  name = tostring(name or ''):gsub('[\r\n]', ' ')
  message = tostring(message or ''):gsub('[\r\n]+', ' ')
  if name == '' or message == '' then return false, 'bad_input' end
  if #name > 64 then name = name:sub(1, 64) end
  if #message > C.InboundMaxLen then message = message:sub(1, C.InboundMaxLen) end
  local n = #GetPlayers()
  TriggerClientEvent('chat:addMessage', -1, {
    color = C.InboundColor,
    multiline = true,
    args = { ('%s %s'):format(C.InboundPrefix, name), message },
  })
  print(('[flrp_chatbridge] %s %s: %s'):format(C.InboundPrefix, name, message))
  return true, n
end
exports('FromDiscord', fromDiscord)

CreateThread(function()
  Wait(1000)
  print(('[flrp_chatbridge] webhook %s; relaying: %s'):format(webhook() and 'configured' or 'NOT set (flrp_chat_bridge_webhook)',
    (function() local t = {} for k, v in pairs(C.Relay) do if v then t[#t + 1] = k end end table.sort(t) return table.concat(t, ', ') end)()))
end)
