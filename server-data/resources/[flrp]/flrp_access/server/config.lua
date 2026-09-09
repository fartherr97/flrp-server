-- ==========================================================================
-- FLRP :: flrp_access/server/config.lua — gate configuration (from convars)
-- ==========================================================================
-- All values come from private convars (config/secrets.cfg). Nothing here is
-- sent to clients. See config/secrets.example.cfg.
-- ==========================================================================

FLRPA = FLRPA or {}
FLRPA.Config = {}

local function convar(name, default) return GetConvar(name, default or '') end
local function convarBool(name, default)
  local v = string.lower(GetConvar(name, default and 'true' or 'false'))
  return v == 'true' or v == '1' or v == 'yes'
end

function FLRPA.Config.Reload()
  FLRPA.Config.enabled       = convarBool('flrp_access_enabled', true)
  -- If the gate cannot reach Discord (misconfig/outage), should we allow
  -- players in with base 'member' role only? Default FALSE (fail closed).
  FLRPA.Config.failOpen      = convarBool('flrp_access_fail_open', false)

  -- Name enforcement: members of enforced groups (cert civ / staff / LEO) must
  -- have their in-game name match their Discord guild display name. Director &
  -- Ownership are exempt. Default OFF so it never kicks before you're ready —
  -- map every enforced role's Discord id and warn members, THEN turn it on with
  -- `set flrp_name_enforce true` in secrets.cfg.
  FLRPA.Config.nameEnforce   = convarBool('flrp_name_enforce', false)
  -- Extra Discord role ids (comma-separated) whose holders are EXEMPT from
  -- name enforcement on top of Director/Ownership, e.g. department heads who
  -- run callsign-style names. Override with `set flrp_name_exempt_roles "id,id"`
  -- in secrets.cfg; the default is the Department Head role.
  FLRPA.Config.nameExemptRoles = {}
  for id in convar('flrp_name_exempt_roles', '1534380750173110282'):gmatch('[^,%s]+') do
    FLRPA.Config.nameExemptRoles[id] = true
  end

  FLRPA.Config.token         = convar('flrp_discord_token')
  FLRPA.Config.guildId       = convar('flrp_discord_guild_id')
  FLRPA.Config.inviteUrl     = convar('flrp_discord_invite_url', 'https://discord.gg/REPLACE_ME')
  FLRPA.Config.communityRole = convar('flrp_role_community_member')

  FLRPA.Config.configured = FLRPA.Config.token ~= '' and FLRPA.Config.token ~= 'REPLACE_ME'
    and FLRPA.Config.guildId ~= '' and FLRPA.Config.guildId ~= 'REPLACE_ME'
end

FLRPA.Config.Reload()

function FLRPA.Config.IsCommunityRoleRequired()
  local r = FLRPA.Config.communityRole
  return r ~= nil and r ~= '' and r ~= 'REPLACE_ME'
end
