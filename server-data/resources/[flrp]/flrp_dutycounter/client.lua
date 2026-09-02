-- ==========================================================================
-- FLRP :: flrp_dutycounter/client.lua — feeds the HUD counter NUI
-- ==========================================================================

RegisterNetEvent('flrp_dutycounter:update', function(data)
  SendNUIMessage({
    type = 'update',
    leo = (data and data.leo) or 0,
    staff = (data and data.staff) or 0,
  })
end)

AddEventHandler('onClientResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  Wait(500)
  TriggerServerEvent('flrp_dutycounter:request')
end)

-- Ask again once the player is fully in the session (covers first spawn).
CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  Wait(1000)
  TriggerServerEvent('flrp_dutycounter:request')
end)
