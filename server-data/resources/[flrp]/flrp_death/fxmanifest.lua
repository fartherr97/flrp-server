-- ==========================================================================
-- FLRP :: flrp_death — death timer, respawn & revive
-- ==========================================================================
-- 60s red respawn countdown for regular players (staff/dir/owner bypass),
-- press-a-key respawn at the nearest hospital, /revive with a server-enforced
-- timer gate, and no voice chat while dead. No external dependencies.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_death'
author 'Florida Roleplay (FLRP)'
description 'FLRP death timer, respawn and revive system'
version '0.1.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

-- Soft runtime dep: flrp_notify (toasts). Needs baseevents (already ensured).
