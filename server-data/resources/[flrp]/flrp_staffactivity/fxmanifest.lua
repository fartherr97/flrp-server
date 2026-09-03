fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'Staff activity tracker: vest-hours + report-claims, posted to Discord SSRP-style'
version '1.0.0'
lua54 'yes'

dependency 'flrp_core'

shared_script 'config.lua'
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server.lua',
}
