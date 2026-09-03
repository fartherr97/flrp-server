-- ==========================================================================
-- FLRP :: flrp_duty — duty adapter over nex-duty
-- ==========================================================================
-- nex-duty (Nexeum) owns duty: its /duty menu, entities, ranks, loadouts, blips,
-- and it records the live on-duty roster in its MySQL table `duty_members`.
-- This resource is now a THIN, READ-ONLY ADAPTER: it keeps the flrp_duty export
-- surface (GetDuty/IsOnDuty) so flrp_economy department pay is unchanged, but
-- sources the answer from nex-duty instead of its own duty state. See
-- docs/SCRIPTS.md and docs/DEPARTMENTS.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_duty'
author 'Florida Roleplay (FLRP)'
description 'FLRP duty adapter — reads department duty from flrp_onduty (flrp_duty_members)'
version '0.2.0'

dependency 'flrp_core'
-- Runtime: reads nex-duty's `duty_members` table (same MySQL via oxmysql).

shared_scripts { 'shared/config.lua' }

server_scripts {
  -- Shared flrp_core server libs (FiveM resources have separate Lua states,
  -- so each resource loads its own copy of the DB/logging/util helpers). The
  -- oxmysql lib provides the MySQL global these wrappers call.
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server/duty.lua',
  'server/exports.lua',
  'server/main.lua',
}

server_exports {
  'GetDuty',
  'IsOnDuty',
  'GetOnDutyRoster',
  'Invalidate',
}
