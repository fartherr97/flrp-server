-- ==========================================================================
-- FLRP :: flrp_messages — in-game private messages (PM/DM)
-- ==========================================================================
-- Jail-styled Messages panel (/pm or keybind) with a quick /pm <id> <msg>,
-- a staff "Monitor" tab that mirrors every PM, and Discord logging via
-- flrp_logs (category `pm`). Session-scoped history (in memory).
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_messages'
author 'Florida Roleplay (FLRP)'
description 'In-game private messages with staff monitor + Discord logging'
version '1.0.0'
lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

files {
  'html/index.html',   -- built by the nui/ workspace (React+Vite): npm run build:messages
}
