-- ==========================================================================
-- FLRP :: flrp_logs/client.lua — reports local death to the server for logging
-- Uses baseevents (already ensured). Server builds the webhook embed.
-- ==========================================================================

AddEventHandler('baseevents:onPlayerDied', function(killerType, deathCoords)
  TriggerServerEvent('flrp_logs:death', 'died')
end)

AddEventHandler('baseevents:onPlayerKilled', function(killerId, deathData)
  local weapon = deathData and deathData.weaponhash
  TriggerServerEvent('flrp_logs:death', 'killed', weapon)
end)
