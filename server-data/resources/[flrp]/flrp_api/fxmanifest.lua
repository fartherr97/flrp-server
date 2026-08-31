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
  'server/router.lua',
  'server/handlers.lua',
  'server/main.lua',
}
