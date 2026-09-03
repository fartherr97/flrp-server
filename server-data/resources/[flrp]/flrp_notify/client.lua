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
