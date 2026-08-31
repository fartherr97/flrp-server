-- ==========================================================================
-- FLRP :: flrp_duty/server/main.lua — boot + wiring
-- ==========================================================================

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRP.Logger.Info('duty', 'flrp_duty ready')
end)

AddEventHandler('flrp_core:playerLoaded', function(source, playerId, record)
  FLRPD.Load(source, playerId)
end)

AddEventHandler('flrp_core:playerDropped', function(source, playerId)
  FLRPD.Remove(source)
end)

-- Client duty request (net event). SERVER validates department role — a
-- client cannot spoof itself on duty. Payload: (department|nil, onDuty:bool).
RegisterNetEvent('flrp_duty:request', function(department, onDuty)
  local source = tonumber(source)
  local ok, err = FLRPD.SetDuty(source, department, onDuty and true or false)
  TriggerClientEvent('flrp_duty:result', source, ok, err)
end)

-- Server command: /duty <bcso|fhp|mpd|off>. Authoritative; source is trusted
-- (server-issued command) but role check still applies inside SetDuty.
RegisterCommand('duty', function(source, args)
  if source == 0 then print('[FLRP] /duty is in-game only') return end
  local arg = string.lower(args[1] or '')
  if arg == '' or arg == 'off' or arg == 'civ' or arg == 'civilian' then
    FLRPD.GoOffDuty(source)
    return
  end
  local ok, err = FLRPD.SetDuty(source, arg, true)
  if not ok then
    TriggerClientEvent('chat:addMessage', source, {
      color = { 200, 60, 60 },
      args = { 'FLRP Duty', ('Could not go on duty: %s'):format(err or 'error') },
    })
  end
end, false)
