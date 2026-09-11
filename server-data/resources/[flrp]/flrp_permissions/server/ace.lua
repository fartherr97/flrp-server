-- ==========================================================================
-- FLRP :: flrp_permissions/server/ace.lua — dynamic ACE principal sync
-- ==========================================================================
-- Adds/removes ACE group principals for a player based on their resolved FLRP
-- roles, so third-party ACE consumers (vMenu) honour the FLRP weapon policy
-- WITHOUT any player's Discord ID being written into permissions.cfg.
--
-- The group.flrp.* hierarchy + vMenu ace mapping is declared statically in
-- config/permissions.cfg. Here we only attach the connecting player's
-- principal to the right groups at runtime and detach on drop.
--
-- Principal form uses the player's license identifier. NOTE: verify the exact
-- principal syntax against your FiveM artifact + vMenu version during runtime
-- testing (see docs/WEAPONS.md); the group names are stable regardless.
-- ==========================================================================

FLRPP = FLRPP or {}
FLRPP.Ace = {}

-- Roles we actually mirror into ACE groups (group.flrp.<key> must exist in
-- config/permissions.cfg). Certifications + departments + staff + base.
local ACE_ROLE_KEYS = {
  member = true, moderator = true, administrator = true, director = true,
  ownership = true, cert_civ_1 = true, cert_civ_2 = true, cert_civ_3 = true,
  bso = true, fhp = true, mpd = true,
  -- Extended staff ranks + civilian leadership (distinct roles; each inherits
  -- its nearest tier's group in permissions.cfg).
  trial_mod = true, senior_mod = true, junior_admin = true,
  senior_admin = true, lead_admin = true,
  civ_supervisor = true, civ_manager = true,
  -- Capability roles (ACE group only): SWAT -> full-auto; Dev -> jg-handling
  -- editor; Media -> vMenu time & weather; leo_access -> LEO spawn points;
  -- donator -> flrp.donator (Donator Vehicles heading in the M menu).
  swat = true, dev = true, media = true, leo_access = true, donator = true,
}

-- Track applied principals per license so we can cleanly remove them.
FLRPP.Ace.applied = {} -- license -> { groupName = true }

local function principalId(license)
  -- FiveM principal for a specific player by license identifier.
  return ('identifier.license:%s'):format(license)
end

function FLRPP.Ace.Apply(license, roleKeys)
  if not license then return end
  FLRPP.Ace.Remove(license) -- clear any stale grants first
  local applied = {}
  local pid = principalId(license)
  for key in pairs(roleKeys) do
    if ACE_ROLE_KEYS[key] then
      local group = ('group.flrp.%s'):format(key)
      ExecuteCommand(('add_principal %s %s'):format(pid, group))
      applied[group] = true
    end
  end
  FLRPP.Ace.applied[license] = applied
  FLRP.Logger.Debug('permissions', 'ACE principals applied', { license = license, groups = applied })
end

function FLRPP.Ace.Remove(license)
  if not license then return end
  local applied = FLRPP.Ace.applied[license]
  if not applied then return end
  local pid = principalId(license)
  for group in pairs(applied) do
    ExecuteCommand(('remove_principal %s %s'):format(pid, group))
  end
  FLRPP.Ace.applied[license] = nil
end
