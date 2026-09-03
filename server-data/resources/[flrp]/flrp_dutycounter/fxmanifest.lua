fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'On-duty HUD counter (LEO from flrp_onduty via flrp_duty; Staff via /vest)'
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
