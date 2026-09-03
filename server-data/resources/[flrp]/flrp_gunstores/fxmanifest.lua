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
  -- Shared flrp_core server libs (FiveM resources have separate Lua states,
  -- so each resource loads its own copy of the DB/logging/util helpers). The
  -- oxmysql lib provides the MySQL global these wrappers call.
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server/purchase.lua',
  'server/main.lua',
}

ui_page 'html/index.html'
files {
  'html/index.html',   -- built by the nui/ workspace (React+Vite); run `npm run build:gunstores`
}
