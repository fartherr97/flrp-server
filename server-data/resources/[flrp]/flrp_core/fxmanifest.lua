-- ==========================================================================
-- FLRP :: flrp_core — shared server services
-- ==========================================================================
-- The foundation resource every other flrp_* resource depends on. Provides
-- player identity, the player cache, configuration access, logging, and a
-- small oxmysql helper. flrp_core itself depends ONLY on oxmysql — it never
-- depends on another flrp_* resource, which keeps the dependency graph acyclic.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_core'
author 'Florida Roleplay (FLRP)'
description 'FLRP shared server services: identity, cache, config, logging'
version '0.1.0'

dependency 'oxmysql'

shared_scripts {
  'shared/config.lua',
  'shared/constants.lua',
}

server_scripts {
  'server/util.lua',
  'server/db.lua',
  'server/config.lua',
  'server/logging.lua',
  'server/identity.lua',
  'server/cache.lua',
  'server/player.lua',
  'server/exports.lua',
  'server/main.lua',
}

-- Exports (see server/exports.lua for the documented API surface)
server_exports {
  'IsReady',
  'GetPlayer',
  'GetPlayerBySource',
  'GetPlayerId',
  'GetPlayerByLicense',
  'GetIdentifiers',
  'GetDiscordId',
  'GetConfig',
  'SetConfig',
  'Log',
  'Audit',
}
