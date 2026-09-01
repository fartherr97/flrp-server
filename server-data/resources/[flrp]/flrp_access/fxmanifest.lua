-- ==========================================================================
-- FLRP :: flrp_access — Discord membership connection gate
-- ==========================================================================
-- Enforces "must be a verified member of the FLRP Discord to join" using
-- server-side playerConnecting deferrals. Reads the member's Discord roles and
-- hands them to flrp_permissions. The bot token is read from a private convar
-- and NEVER leaves the server. See docs/DISCORD_INTEGRATION.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_access'
author 'Florida Roleplay (FLRP)'
description 'DEPRECATED (superseded by pCore) — FLRP Discord-gated connection deferrals'
version '0.1.0'

dependency 'flrp_core'
-- Soft dependency on flrp_permissions (communicates via server event, so not
-- a hard load-order requirement, but should start after it — see resources.cfg).

server_scripts {
  'server/config.lua',
  'server/discord.lua',
  'server/main.lua',
}
