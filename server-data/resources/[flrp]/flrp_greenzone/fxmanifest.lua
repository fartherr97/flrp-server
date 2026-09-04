-- ==========================================================================
-- FLRP :: flrp_greenzone — safe zones (green zones)
-- ==========================================================================
-- Ownership /greenzones manager to create circular safe zones in-game and
-- toggle weapons/damage/vehicles per zone. DB-persisted, synced live, enforced
-- client-side with a map blip and entry/exit notice.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_greenzone'
author 'Florida Roleplay (FLRP)'
description 'Safe zones with an in-game ownership manager'
version '0.1.0'
lua54 'yes'

dependency 'flrp_core'

ui_page 'html/index.html'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server.lua',
}

files {
  'html/index.html',   -- built by the nui/ workspace: node build.mjs greenzone
}
