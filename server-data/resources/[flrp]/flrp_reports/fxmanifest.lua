fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'Staff report system: /report + /calladmin, J-key console, claims, messaging, goto/bring, analytics leaderboard'
version '1.0.0'
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
  'html/index.html',
  'html/style.css',
  'html/app.js',
}
