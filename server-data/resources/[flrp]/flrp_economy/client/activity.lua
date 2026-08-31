-- ==========================================================================
-- FLRP :: flrp_economy/client/activity.lua — activity heartbeat (hint only)
-- ==========================================================================
-- Sends a lightweight "I'm active" heartbeat to the server ONLY when the local
-- player is spawned and has recently produced control input. This is a HINT:
-- the server independently validates activity (GetPlayerLastMsg) and computes
-- all pay server-side, so this cannot be used to farm money while AFK. See
-- docs/ECONOMY.md / docs/SECURITY.md.
-- ==========================================================================

local lastInputTime = 0

-- Controls that count as "the player is doing something" (movement, look,
-- attack, enter vehicle, jump, etc.). Kept broad but not idle-noise.
local ACTIVITY_CONTROLS = { 30, 31, 32, 33, 34, 35, 21, 22, 24, 25, 23, 75, 1, 2 }

CreateThread(function()
  while true do
    Wait(500)
    local moved = false
    for _, c in ipairs(ACTIVITY_CONTROLS) do
      if IsControlPressed(0, c) or IsDisabledControlPressed(0, c) then
        moved = true
        break
      end
    end
    if moved then lastInputTime = GetGameTimer() end
  end
end)

CreateThread(function()
  while true do
    Wait(FLRPE.Config.HeartbeatIntervalMs)
    local ped = PlayerPedId()
    local spawned = ped and ped ~= 0 and not IsEntityDead(ped)
    local recentlyActive = (GetGameTimer() - lastInputTime) <= FLRPE.Config.ClientActivityWindowMs
    if spawned and recentlyActive then
      TriggerServerEvent('flrp_economy:activityPing')
    end
  end
end)
