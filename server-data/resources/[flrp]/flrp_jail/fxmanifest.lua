-- ==========================================================================
-- FLRP :: flrp_jail — Jail Manager + Hospitalize
-- ==========================================================================
-- Staff /jail manager (React NUI): jail (red), hospitalize (green, hospital
-- selector), and a blue LEO Hospitalize (2m, LEO-on-LEO). Jail persists across
-- relogs. All privileged actions re-checked server-side.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_jail'
author 'Florida Roleplay (FLRP)'
description 'Jail Manager + Hospitalize with hospital selector'
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
  'html/index.html',   -- built by the nui/ workspace (React+Vite): npm run build -- jail
}
