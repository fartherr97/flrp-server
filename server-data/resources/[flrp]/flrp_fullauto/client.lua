-- ==========================================================================
-- FLRP :: flrp_fullauto/client.lua — semi-auto lock for non-authorized players
-- ==========================================================================
-- If the player isn't allowed full-auto, every weapon becomes one-shot-per-
-- trigger-pull: after a shot lands we disable the attack input until the
-- trigger is released, so holding fire can't spray. Already-semi weapons are
-- unaffected (they were one-per-press anyway). Authorized players are left
-- completely alone.
-- ==========================================================================

local INPUT_ATTACK, INPUT_ATTACK2 = 24, 257
local canSniper = false
local canAuto = false   -- fail safe: locked until the server confirms access

local function refresh() TriggerServerEvent('flrp_fullauto:check') end

RegisterNetEvent('flrp_fullauto:set', function(v, sniper) canAuto = v == true; canSniper = sniper == true end)

-- Ask on resource start, once in-session, then re-verify on a timer.
AddEventHandler('onClientResourceStart', function(res)
  if res == GetCurrentResourceName() then refresh() end
end)
CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  refresh()
  local every = (FLRP_FULLAUTO.RecheckSeconds or 60) * 1000
  while true do
    Wait(every)
    refresh()
  end
end)

-- The semi-auto lock.
CreateThread(function()
  local blocked = false
  while true do
    if canAuto then
      blocked = false
      Wait(500)          -- authorized: idle, zero gameplay impact
    else
      Wait(0)
      local ped = PlayerPedId()
      if IsPedShooting(ped) then blocked = true end
      if blocked then
        DisableControlAction(0, INPUT_ATTACK, true)
        DisableControlAction(0, INPUT_ATTACK2, true)
        DisablePlayerFiring(PlayerId(), true)
        -- Released the trigger? unlock so the next pull fires a single shot.
        if not IsDisabledControlPressed(0, INPUT_ATTACK) and not IsControlPressed(0, INPUT_ATTACK) then
          blocked = false
        end
      end
    end
  end
end)

-- Remove unauthorized sniper grants from menus, saved loadouts and pickups.
-- Block firing each frame, so the removal interval cannot allow a quick shot.
local snipers = {}
for _, name in ipairs(FLRP_FULLAUTO.Snipers) do snipers[GetHashKey(name)] = true end
CreateThread(function()
    local nextSweep = 0
    while true do
        if canSniper then Wait(250) else
            Wait(0)
            local ped = PlayerPedId()
            if snipers[GetSelectedPedWeapon(ped)] then
                DisablePlayerFiring(PlayerId(), true)
                SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            end
            if GetGameTimer() >= nextSweep then
                for hash in pairs(snipers) do
                    if HasPedGotWeapon(ped, hash, false) then RemoveWeaponFromPed(ped, hash) end
                end
                nextSweep = GetGameTimer() + 250
            end
        end
    end
end)
