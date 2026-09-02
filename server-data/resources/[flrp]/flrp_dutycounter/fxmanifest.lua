fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'On-duty HUD counter (LEO from nex-duty via flrp_duty; Staff via /sd toggle or vest export)'
version '1.0.0'
lua54 'yes'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}

client_script 'client.lua'
server_script 'server.lua'
