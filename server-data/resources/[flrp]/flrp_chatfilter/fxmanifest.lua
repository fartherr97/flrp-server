-- ==========================================================================
-- FLRP :: flrp_chatfilter — zero-tolerance slur filter
-- ==========================================================================
-- Blocks severe slurs from chat, auto-kicks the sender, and posts a Discord
-- embed pinging the staff role. Consumed by flrp_chat (and flrp_messages) via
-- exports; must load before them. Ordinary profanity passes through.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

author 'FLRP'
description 'Slur filter: block chat + auto-kick + staff Discord ping'
version '1.0.0'
lua54 'yes'

shared_script 'config.lua'
server_script 'server.lua'
