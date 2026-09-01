-- ==========================================================================
-- FLRP :: flrp_api — HTTP contract for the FLRP Manager website
-- ==========================================================================
-- A thin, authenticated HTTP surface so the EXISTING FLRP Manager (a separate
-- repository) can read and control FiveM settings — permissions, roles,
-- vehicles, weapons, economy, departments, audit logs. This does NOT include a
-- UI: it is the backend contract only. Every request must carry the shared
-- secret; every write is audited. See docs/WEBSITE_INTEGRATION.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_api'
author 'Florida Roleplay (FLRP)'
description 'FLRP Manager API contract (authenticated HTTP endpoints)'
version '0.1.0'

dependency 'flrp_core'
-- runtime export deps: flrp_permissions, flrp_economy, flrp_weapons, flrp_vehicles

server_scripts {
  -- Shared flrp_core server libs (FiveM resources have separate Lua states,
  -- so each resource loads its own copy of the DB/logging/util helpers). The
  -- oxmysql lib provides the MySQL global these wrappers call.
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server/router.lua',
  'server/sync.lua',
  'server/handlers.lua',
  'server/main.lua',
}
