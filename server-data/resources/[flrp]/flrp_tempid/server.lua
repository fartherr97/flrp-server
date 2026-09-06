-- ==========================================================================
-- FLRP :: flrp_tempid/server.lua — gate + Discord log for Temp ID
-- ==========================================================================

local function isLeo(src) return IsPlayerAceAllowed(src, FLRP_TEMPID.Ace) end

RegisterNetEvent('flrp_tempid:use', function()
  local src = source
  if not isLeo(src) then return end   -- silently ignore non-LEO requests

  TriggerClientEvent('flrp_tempid:show', src)

  pcall(function()
    exports.flrp_logs:Send('tempid', {
      player = src,
      description = ('**%s** used **Temp ID** — revealed nearby players\' IDs.')
        :format(GetPlayerName(src) or ('Player ' .. src)),
    })
  end)
end)
