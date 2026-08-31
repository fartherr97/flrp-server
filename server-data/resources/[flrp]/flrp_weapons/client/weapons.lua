-- ==========================================================================
-- FLRP :: flrp_weapons/client/weapons.lua — apply owned weapons on spawn
-- ==========================================================================
-- Re-applies the player's server-owned weapons to their ped after each spawn.
-- This is presentation of a server-authoritative ownership list — the server
-- decides ownership; the client just gives the models it was told to. (FiveM
-- cannot prevent external mod menus from spawning weapons; that is a separate
-- anti-cheat concern documented in docs/SECURITY.md. What IS enforced here is
-- the FLRP policy: only owned/authorized weapons are granted through FLRP.)
-- ==========================================================================

local ownedWeapons = {}

local function applyOwned()
  local ped = PlayerPedId()
  if not ped or ped == 0 then return end
  for _, name in ipairs(ownedWeapons) do
    local hash = GetHashKey(name)
    GiveWeaponToPed(ped, hash, 0, false, false) -- 0 ammo; ammo handled elsewhere
  end
end

RegisterNetEvent('flrp_weapons:setOwned', function(list)
  ownedWeapons = list or {}
  applyOwned()
end)

RegisterNetEvent('flrp_weapons:grant', function(name)
  if not name then return end
  -- add to local list if new
  local exists = false
  for _, n in ipairs(ownedWeapons) do if n == name then exists = true break end end
  if not exists then ownedWeapons[#ownedWeapons + 1] = name end
  local ped = PlayerPedId()
  if ped and ped ~= 0 then GiveWeaponToPed(ped, GetHashKey(name), 0, false, false) end
end)

-- Re-apply on spawn.
AddEventHandler('playerSpawned', function()
  -- Ask the server for a fresh list in case ownership changed while dead/loading.
  TriggerServerEvent('flrp_weapons:requestOwned')
  Wait(500)
  applyOwned()
end)
