-- ==========================================================================
-- FLRP :: flrp_permissions/server/pcore.lua — pCore bridge
-- ==========================================================================
-- FLRP reads a player's FLRP role membership from pCore SYNCHRONOUSLY via ACE.
-- pCore attaches each player's principal to their group principals
-- (add_principal identifier.discord:<id> <group>); config/permissions.cfg maps
-- each pCore group to an ace `flrp.role.<key>`. So IsPlayerAceAllowed(src,
-- 'flrp.role.<key>') tells us whether the player is in that FLRP role — no
-- async calls into pCore, no edits to pCore. See docs/PCORE_INTEGRATION.md.
--
-- If pCore's group names change (configs/playerPerms.ts), update BOTH the
-- add_ace lines in permissions.cfg and this map together.
-- ==========================================================================

FLRPP = FLRPP or {}
FLRPP.PCore = {}

-- FLRP role key -> the ace granted (via permissions.cfg) to pCore's matching
-- group principal. Every verified player is 'member'.
local ROLE_ACE = {
  ownership     = 'flrp.role.ownership',
  director      = 'flrp.role.director',
  administrator = 'flrp.role.administrator',
  moderator     = 'flrp.role.moderator',
  member        = 'flrp.role.member',
  cert_civ_1    = 'flrp.role.cert_civ_1',
  cert_civ_2    = 'flrp.role.cert_civ_2',
  cert_civ_3    = 'flrp.role.cert_civ_3',
  bcso          = 'flrp.role.bcso',
  fhp           = 'flrp.role.fhp',
  mpd           = 'flrp.role.mpd',
}

-- Build the set of FLRP role keys a connected source holds, from pCore ACE.
-- Returns { [roleKey] = true }. A connected player is always at least 'member'.
function FLRPP.PCore.GetFlrpRoleKeys(source)
  source = tonumber(source)
  local roles = {}
  if not source then return roles end
  for key, ace in pairs(ROLE_ACE) do
    if IsPlayerAceAllowed(source, ace) then
      roles[key] = true
    end
  end
  -- Verified players are members even if the base ace was not attached yet.
  roles.member = true
  return roles
end

-- Is pCore present/started? (informational; the ACE bridge works regardless)
function FLRPP.PCore.Available()
  return GetResourceState and GetResourceState('pCore') == 'started'
end
