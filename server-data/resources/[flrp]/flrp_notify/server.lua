-- ==========================================================================
-- FLRP :: flrp_notify/server.lua — broadcast join / leave to all clients
-- ==========================================================================
-- playerJoining fires once flrp_access has allowed the player through the
-- connection gate, so only verified players ever produce a "joined" toast.
-- playerDropped covers every disconnect type (quit, timeout, kick, crash).
-- ==========================================================================

AddEventHandler('playerJoining', function()
  local src = source
  local name = GetPlayerName(src)
  if name and name ~= '' then
    TriggerClientEvent('flrp_notify:show', -1, 'join', name)
  end
end)

AddEventHandler('playerDropped', function()
  local src = source
  local name = GetPlayerName(src)   -- still valid during the drop event
  if name and name ~= '' then
    TriggerClientEvent('flrp_notify:show', -1, 'leave', name)
  end
end)
