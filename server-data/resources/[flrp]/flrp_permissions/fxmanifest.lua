-- ==========================================================================
-- FLRP :: flrp_permissions — centralized permission engine + ACE sync
-- ==========================================================================
-- ONE place that answers "may this player do X?". Loads roles / permissions /
-- role_permissions / discord_role_mappings from the DB, resolves each player's
-- effective permission set (with inheritance + deny-beats-allow), and syncs
-- ACE principals so vMenu honours the FLRP weapon-spawn policy dynamically.
--
-- Depends on flrp_core only. Other resources call
-- exports.flrp_permissions:HasPermission(source, key) — they NEVER do raw
-- Discord role checks themselves. See docs/PERMISSIONS.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_permissions'
author 'Florida Roleplay (FLRP)'
description 'FLRP centralized permission engine and ACE/vMenu synchronization'
version '0.1.0'

dependency 'flrp_core'

server_scripts {
  'server/store.lua',
  'server/pcore.lua',
  'server/resolver.lua',
  'server/permissions.lua',
  'server/exports.lua',
  'server/main.lua',
}

server_exports {
  'HasPermission',
  'HasAnyPermission',
  'GetRoles',
  'IsInGroup',
  'GetEffectivePermissions',
  'ReloadPermissions',
  'ApplyForSource',
  'GetPermissionMatrix',
}
