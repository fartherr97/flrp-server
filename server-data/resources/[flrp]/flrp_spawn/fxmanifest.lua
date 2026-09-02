fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'flrp_spawn'
author 'Florida Roleplay (FLRP)'
description 'FLRP spawn selector — open, debuggable replacement for nex-spawn'
version '1.0.0'

-- Depends on spawnmanager (cfx-server-data base resource) for the actual spawn.
dependency 'spawnmanager'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
