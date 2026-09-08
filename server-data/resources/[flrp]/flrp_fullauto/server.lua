-- ==========================================================================
-- FLRP :: flrp_fullauto/server.lua — authoritative full-auto access check
-- ==========================================================================

local function allowed(src) return IsPlayerAceAllowed(src, FLRP_FULLAUTO.Ace) end

-- Client asks whether it may fire full-auto (on spawn + on a timer).
RegisterNetEvent('flrp_fullauto:check', function()
  local src = source
  TriggerClientEvent('flrp_fullauto:set', src, allowed(src))
end)

-- Optional: other resources can ask, e.g. after a role change.
exports('IsAllowed', function(src)
  src = tonumber(src)
  return src and allowed(src) or false
end)
