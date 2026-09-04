-- ==========================================================================
-- FLRP :: flrp_logs/client.lua — reports local death to the server for logging
-- ==========================================================================
-- Uses baseevents (already ensured). We classify how the player died from the
-- cause-of-death weapon hash (Firearm / Melee / Explosive / Vehicle / Fall /
-- Drowning / Fire / Suicide) and, if another PLAYER did it, pass their server
-- id so the server can build "X was killed by Firearm by Y". The server builds
-- the webhook embed.
--
-- ORDERING NOTE: flrp_logs is ensured BEFORE flrp_death in resources.cfg, so
-- this baseevents handler runs before flrp_death resurrects the ped in place —
-- that's what keeps GetPedCauseOfDeath / GetPedSourceOfDeath readable here.
-- Keep flrp_logs ahead of flrp_death if you reorder resources.
-- ==========================================================================

-- Named death causes that aren't a normal weapon group (compile-time joaat
-- hashes via `backticks`). Anything not here falls back to its weapon group.
local CAUSE_LABEL = {
  [`WEAPON_FALL`]                = 'Fall',
  [`WEAPON_DROWNING`]            = 'Drowning',
  [`WEAPON_DROWNING_IN_VEHICLE`] = 'Drowning',
  [`WEAPON_FIRE`]                = 'Fire',
  [`WEAPON_EXPLOSION`]           = 'Explosion',
  [`WEAPON_RAMMED_BY_CAR`]       = 'Vehicle',
  [`WEAPON_RUN_OVER_BY_CAR`]     = 'Vehicle',
  [`WEAPON_UNARMED`]             = 'Melee',
}

-- Weapon groups bucketed into the labels we report.
local GROUP_FIREARM = {
  [`GROUP_PISTOL`] = true, [`GROUP_SMG`]     = true, [`GROUP_RIFLE`]  = true,
  [`GROUP_MG`]     = true, [`GROUP_SHOTGUN`] = true, [`GROUP_SNIPER`] = true,
  [`GROUP_HEAVY`]  = true, [`GROUP_STUNGUN`] = true,
}
local GROUP_MELEE  = { [`GROUP_MELEE`] = true, [`GROUP_UNARMED`] = true }
local GROUP_THROWN = { [`GROUP_THROWN`] = true, [`GROUP_PETROLCAN`] = true }

local function classify(hash, selfKill)
  if selfKill then return 'Suicide' end
  local named = CAUSE_LABEL[hash]
  if named then return named end
  local g = GetWeapontypeGroup(hash)
  if GROUP_FIREARM[g] then return 'Firearm' end
  if GROUP_MELEE[g]   then return 'Melee' end
  if GROUP_THROWN[g]  then return 'Explosive' end
  return 'Unknown'
end

local lastReport = 0

local function report()
  local now = GetGameTimer()
  if now - lastReport < 2000 then return end   -- debounce: only one event per death
  lastReport = now

  local ped   = PlayerPedId()
  local hash  = GetPedCauseOfDeath(ped)
  local src   = GetPedSourceOfDeath(ped)
  local selfKill = (src == ped)

  -- Was the killer another player? (NPC / environment -> no killer name)
  local killerSid
  if src and src ~= 0 and src ~= ped and IsEntityAPed(src) and IsPedAPlayer(src) then
    local pl = NetworkGetPlayerIndexFromPed(src)
    if pl and pl ~= -1 then killerSid = GetPlayerServerId(pl) end
  end

  TriggerServerEvent('flrp_logs:death', classify(hash, selfKill), killerSid)
end

AddEventHandler('baseevents:onPlayerDied',   report)
AddEventHandler('baseevents:onPlayerKilled', report)
