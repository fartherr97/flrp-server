-- ==========================================================================
-- FLRP :: flrp_weapons — weapon registry + persistent ownership
-- ==========================================================================
-- Centralized weapon registry (the model + authoritative prices/eligibility)
-- and per-player persistent weapon ownership. flrp_gunstores uses this registry
-- for authoritative prices and records ownership here. Owned weapons are
-- re-applied on spawn. See docs/WEAPONS.md.
--
-- The PRODUCTION catalog is NOT seeded here — only clearly-labelled DEV/TEST
-- entries (migration 008) exist until the real catalog is imported.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_weapons'
author 'Florida Roleplay (FLRP)'
description 'FLRP weapon registry and persistent weapon ownership'
version '0.1.0'

dependency 'flrp_core'

client_scripts { 'client/weapons.lua' }

server_scripts {
  -- Shared flrp_core server libs (FiveM resources have separate Lua states,
  -- so each resource loads its own copy of the DB/logging/util helpers). The
  -- oxmysql lib provides the MySQL global these wrappers call.
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server/registry.lua',
  'server/ownership.lua',
  'server/exports.lua',
  'server/main.lua',
}

server_exports {
  'GetWeapon',
  'GetStoreCatalog',
  'GetAuthoritativePrice',
  'IsGunstoreAvailable',
  'IsVMenuSpawnable',
  'OwnsWeapon',
  'GetOwnedWeapons',
  'RecordOwnership',
  'ReloadRegistry',
}
