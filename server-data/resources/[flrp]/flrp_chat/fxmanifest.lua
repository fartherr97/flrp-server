fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'FLRP chat: Discord-colored staff names + ACE-gated /sc /ac /dc channels'
version '1.0.0'
lua54 'yes'

-- Renders through the base `chat` resource (chat:addMessage). Gating uses the
-- flrp.staff.* ACEs granted in config/permissions.cfg.
shared_script 'config.lua'
server_script 'server.lua'
