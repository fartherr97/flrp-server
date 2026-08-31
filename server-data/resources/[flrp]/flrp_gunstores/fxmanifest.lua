-- ==========================================================================
-- FLRP :: flrp_gunstores — gun store purchase flow + NUI
-- ==========================================================================
-- Where players WITHOUT weapon.vmenu.spawn obtain weapons. Every purchase is
-- validated server-side end-to-end (player -> weapon -> eligibility ->
-- permission -> authoritative price -> balance -> atomic deduct -> ledger ->
-- ownership -> grant), with proximity + idempotency + in-flight locks to defeat
-- duplicate/race purchases. The client displays prices but the SERVER fetches
-- and validates the authoritative price independently. See docs/WEAPONS.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_gunstores'
author 'Florida Roleplay (FLRP)'
description 'FLRP gun stores: secure weapon purchasing with persistent ownership'
version '0.1.0'

dependency 'flrp_core'
-- runtime export deps: flrp_weapons, flrp_economy, flrp_permissions

shared_scripts { 'shared/config.lua' }

client_scripts { 'client/main.lua' }

server_scripts {
  'server/purchase.lua',
  'server/main.lua',
}

ui_page 'nui/index.html'
files {
  'nui/index.html',
  'nui/style.css',
  'nui/app.js',
}
