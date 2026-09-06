-- ==========================================================================
-- FLRP :: flrp_messages/client.lua — panel focus + NUI bridge + quick send
-- ==========================================================================

local isOpen, pending, seq = false, {}, 0

local function request(action, payload, cb)
  seq = seq + 1; pending[seq] = cb
  TriggerServerEvent('flrp_messages:req', action, payload or {}, seq)
end
RegisterNetEvent('flrp_messages:res', function(id, data)
  local cb = pending[id]; pending[id] = nil
  if cb then cb(data) end
end)

local function notify(title, body)
  TriggerEvent('flrp_notify:toast', { title = title, kind = 'info', body = body })
end

local function close()
  isOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

local function open()
  request('open', {}, function(state)
    if not state or not state.ok then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state })
  end)
end

-- /pm            -> open/close the panel
-- /pm <id> <msg> -> quick-send without opening
RegisterCommand(FLRP_MESSAGES.Command, function(_, args)
  args = args or {}
  if args[1] and tonumber(args[1]) and args[2] then
    TriggerServerEvent('flrp_messages:quick', tonumber(args[1]), table.concat(args, ' ', 2))
    return
  end
  if isOpen then close() else open() end
end, false)
RegisterKeyMapping(FLRP_MESSAGES.Command, 'FLRP: Open Messages', 'keyboard', FLRP_MESSAGES.Key)
TriggerEvent('chat:addSuggestion', '/' .. FLRP_MESSAGES.Command, 'Open Messages, or /pm <id> <message> to quick-send', {
  { name = 'id', help = 'server id of the player to message' },
  { name = 'message', help = 'what to say' },
})

if FLRP_MESSAGES.AltCommand and FLRP_MESSAGES.AltCommand ~= '' then
  RegisterCommand(FLRP_MESSAGES.AltCommand, function() if isOpen then close() else open() end end, false)
  TriggerEvent('chat:addSuggestion', '/' .. FLRP_MESSAGES.AltCommand, 'Open the Messages panel')
end

RegisterNUICallback('close', function(_, cb) close(); cb({}) end)
RegisterNUICallback('req', function(data, cb)
  request(data and data.action, data and data.payload, function(res) cb(res or { ok = false, error = 'No response.' }) end)
end)

-- Live pushes from the server.
RegisterNetEvent('flrp_messages:incoming', function(m)
  if isOpen then SendNUIMessage({ action = 'incoming', message = m })
  else notify('New message from ' .. (m.fromName or 'someone'), m.text) end
end)
RegisterNetEvent('flrp_messages:sent', function(m)
  if isOpen then SendNUIMessage({ action = 'sent', message = m }) end
end)
RegisterNetEvent('flrp_messages:monitor', function(m)
  if isOpen then SendNUIMessage({ action = 'monitor', message = m }) end
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
