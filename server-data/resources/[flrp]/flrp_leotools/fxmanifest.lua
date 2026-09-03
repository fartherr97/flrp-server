-- ==========================================================================
-- FLRP :: flrp_leotools — LEO restraint tools (cuff / drag / seat)
-- ==========================================================================
-- Server-authoritative cuff, escort (drag) and put-in-vehicle actions for
-- sworn law enforcement (flrp.leo). Driven from the flrp_interact LEO Toolbox
-- and /cuff, /drag, /seat, /unseat. No external dependencies.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_leotools'
author 'Florida Roleplay (FLRP)'
description 'FLRP LEO restraint tools: cuff, drag/escort, put-in-vehicle'
version '0.1.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

-- Soft runtime deps: flrp_notify (toasts), flrp_logs (jail category).
