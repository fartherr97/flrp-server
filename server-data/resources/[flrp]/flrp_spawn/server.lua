-- ==========================================================================
-- FLRP :: flrp_spawn/server.lua — ace-gated spawn approval
-- ==========================================================================
-- The ace gate is enforced HERE, not on the client. `IsPlayerAceAllowed`
-- resolves the player's principals (group.flrp.* attached at connection), so a
-- civilian can neither see nor spawn at a `flrp.leo`-gated point.
-- ==========================================================================

-- Which points may this player use? (gated points check the ace)
RegisterNetEvent('flrp_spawn:requestPoints', function()
  local src = source
  local allowed = {}
  for i, p in ipairs(Config.Points) do
    if p.ace then
      allowed[i] = IsPlayerAceAllowed(src, p.ace)
    else
      allowed[i] = true
    end
  end
  TriggerClientEvent('flrp_spawn:points', src, allowed)
end)

-- Approve (or deny) a chosen point after re-checking the ace server-side.
RegisterNetEvent('flrp_spawn:selectPoint', function(index)
  local src = source
  index = tonumber(index)
  local p = index and Config.Points[index]
  if not p then return end
  if p.ace and not IsPlayerAceAllowed(src, p.ace) then
    TriggerClientEvent('flrp_spawn:denied', src)
    return
  end
  TriggerClientEvent('flrp_spawn:approved', src, index)
end)
