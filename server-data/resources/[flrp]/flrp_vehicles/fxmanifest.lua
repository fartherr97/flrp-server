-- ==========================================================================
-- FLRP :: flrp_vehicles — vehicle registry + permission engine
-- ==========================================================================
-- Centralized vehicle registry + server-authoritative spawn-permission checks.
-- The registry is INTENTIONALLY EMPTY of real FLRP vehicles until asset import
-- (docs/ASSET_IMPORT.md); the structure/exports are ready so vehicle packs can
-- be registered without code changes. See docs/VEHICLES.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_vehicles'
author 'Florida Roleplay (FLRP)'
description 'FLRP vehicle registry and centralized vehicle permission engine'
version '0.1.0'

dependency 'flrp_core'
-- runtime export dep: flrp_permissions

client_scripts { 'client/main.lua' }

server_scripts {
  -- Shared flrp_core server libs (FiveM resources have separate Lua states,
  -- so each resource loads its own copy of the DB/logging/util helpers). The
  -- oxmysql lib provides the MySQL global these wrappers call.
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server/registry.lua',
  'server/exports.lua',
  'server/main.lua',
}

server_exports {
  'GetVehicle',
  'CanSpawn',
  'ListForPlayer',
  'ReloadRegistry',
  'RegisterVehicle',
}
