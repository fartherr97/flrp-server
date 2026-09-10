-- ==========================================================================
-- FLRP :: flrp_pvp/client.lua — turn player-vs-player damage ON
-- ==========================================================================
-- GTA treats every player as "friendly" by default, so without this nobody can
-- hurt anyone: shots and melee on other players just don't register. Both
-- natives below are per-client and per-ped, so they're re-applied on every
-- spawn (new ped handle) and on a slow safety loop.
--
-- Kill switch without a deploy:  setr flrp_pvp "false"  in secrets.cfg, then
-- restart the resource. Greenzones still make players invincible inside them
-- (flrp_greenzone) — that layer is untouched.
-- ==========================================================================

local function pvpEnabled()
  return GetConvar('flrp_pvp', 'true') ~= 'false'
end

local function applyPvp()
  local on = pvpEnabled()
  NetworkSetFriendlyFireOption(on)
  SetCanAttackFriendly(PlayerPedId(), on, false)
end

AddEventHandler('playerSpawned', applyPvp)

CreateThread(function()
  while true do
    applyPvp()
    Wait(5000)
  end
end)
