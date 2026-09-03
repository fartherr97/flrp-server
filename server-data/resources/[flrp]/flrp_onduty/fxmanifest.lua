fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'FLRP duty system: department on/off duty menu, callsigns, ranks, loadouts (replaces nex-duty)'
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
  'html/index.html',   -- built by the nui/ workspace (React+Vite); run `npm run build:onduty`
}

server_exports {
  'IsOnDuty',
  'GetDuty',
  'GetAll',
  'SetOffDuty',
}
