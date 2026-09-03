-- ==========================================================================
-- FLRP :: flrp_notify/client.lua — relay join/leave to the NUI toast
-- ==========================================================================

RegisterNetEvent('flrp_notify:show', function(kind, name)
  if type(name) ~= 'string' or name == '' then return end
  SendNUIMessage({
    action   = 'notify',
    kind     = (kind == 'leave') and 'leave' or 'join',
    name     = name,
    joinMsg  = FLRP_NOTIFY.JoinText,
    leaveMsg = FLRP_NOTIFY.LeaveText,
    color    = (kind == 'leave') and FLRP_NOTIFY.LeaveColor or FLRP_NOTIFY.JoinColor,
    duration = FLRP_NOTIFY.DurationMs,
    max      = FLRP_NOTIFY.MaxVisible,
  })
end)

-- Generic transient toast for command confirmations / status, so they never
-- land in chat history (which re-shows every time the chatbox opens).
--   TriggerClientEvent('flrp_notify:toast', src, { title=, body=, kind='info'|'ok'|'error', duration= })
local KIND_COLOUR = { info = '#00bfc4', ok = '#35d07f', error = '#ff4d4d' }
RegisterNetEvent('flrp_notify:toast', function(d)
  if type(d) ~= 'table' then return end
  local body = tostring(d.body or '')
  SendNUIMessage({
    action   = 'notify',
    kind     = 'join',                       -- layout only; colour below
    name     = tostring(d.title or 'FLRP'),
    joinMsg  = body, leaveMsg = body,
    color    = d.color or KIND_COLOUR[d.kind or 'info'] or KIND_COLOUR.info,
    duration = tonumber(d.duration) or 5000,
    max      = FLRP_NOTIFY.MaxVisible,
  })
end)
