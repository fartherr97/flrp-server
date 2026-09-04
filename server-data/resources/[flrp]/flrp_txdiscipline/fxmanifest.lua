-- ==========================================================================
-- FLRP :: flrp_txdiscipline — txAdmin discipline events -> Discord
-- ==========================================================================
-- Posts txAdmin bans / kicks / warns / revokes to a Discord channel. Webhook
-- URL is read from the `flrp_txdiscipline_webhook` convar (secrets.cfg) — never
-- hard-coded. Server-only; listens to txAdmin's documented events.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_txdiscipline'
author 'Florida Roleplay (FLRP)'
description 'txAdmin ban/kick/warn discipline logging to Discord'
version '0.1.0'

shared_script 'config.lua'
server_script 'server.lua'
