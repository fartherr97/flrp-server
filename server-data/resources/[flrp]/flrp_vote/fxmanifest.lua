fx_version 'cerulean'
game 'gta5'

name 'flrp_vote'
author 'Florida Roleplay (FLRP)'
description 'In-game votes (AOP votes, polls) — full-screen ballot, staff-started'
version '1.0.0'
lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

files {
  'html/index.html',   -- built by the nui/ workspace: npm run build:vote
}
