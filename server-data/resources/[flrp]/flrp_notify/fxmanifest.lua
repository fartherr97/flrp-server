fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'Custom nex-styled join / leave notifications (replaces the native vMenu ones)'
version '1.0.0'
lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
