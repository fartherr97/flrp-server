-- ==========================================================================
-- FLRP :: flrp_no_peds/client.lua — no wandering NPCs, keep AI traffic
-- ==========================================================================
-- Zeroes pedestrian + scenario-ped density every frame so no NPCs spawn on
-- foot. Vehicle density is left ALONE, so AI traffic (and the drivers that come
-- with those vehicles) keeps spawning normally. Emergency-service auto-dispatch
-- is disabled too so cops/ambulances/firetrucks don't auto-respond to the void
-- left by missing peds.
-- ==========================================================================

CreateThread(function()
  -- Disable the ambient emergency dispatch services (no auto-spawned police
  -- peds, medics, firemen, gang members responding to nothing).
  for i = 1, 15 do
    EnableDispatchService(i, false)
  end

  while true do
    Wait(0)
    -- Foot pedestrians: none.
    SetPedDensityMultiplierThisFrame(0.0)
    SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)

    -- NOTE: vehicle densities are intentionally NOT touched here — that is what
    -- keeps AI traffic alive. Do not add SetVehicleDensityMultiplierThisFrame(0).
  end
end)
