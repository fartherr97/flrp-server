-- ==========================================================================
-- FLRP :: flrp_spawn/server.lua — ace-gated spawn approval
-- ==========================================================================
-- The ace gate is enforced HERE, not on the client. `IsPlayerAceAllowed`
-- resolves the player's principals (group.flrp.* attached at connection), so a
-- civilian can neither see nor spawn at a `flrp.leo`-gated point.
-- Staff (moderator and up, which ownership inherits) bypass every gate so they
-- can reach LEO spawns for testing/admin.
-- ==========================================================================

local STAFF_BYPASS = 'flrp.staff.moderate'

-- True if the player may use a point: ungated, holds its ace, or is staff.
local function canUse(src, p)
  if not p.ace then return true end
  return IsPlayerAceAllowed(src, p.ace) or IsPlayerAceAllowed(src, STAFF_BYPASS)
end

-- Which points may this player use? (gated points check the ace / staff bypass)
RegisterNetEvent('flrp_spawn:requestPoints', function()
  local src = source
  local allowed = {}
  for i, p in ipairs(Config.Points) do
    allowed[i] = canUse(src, p)
  end
  TriggerClientEvent('flrp_spawn:points', src, allowed)
end)

-- Approve (or deny) a chosen point after re-checking the ace server-side.
RegisterNetEvent('flrp_spawn:selectPoint', function(index)
  local src = source
  index = tonumber(index)
  local p = index and Config.Points[index]
  if not p then return end
  if not canUse(src, p) then
    TriggerClientEvent('flrp_spawn:denied', src)
    return
  end
  TriggerClientEvent('flrp_spawn:approved', src, index)
end)
