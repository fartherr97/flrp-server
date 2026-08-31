-- ==========================================================================
-- FLRP :: flrp_duty — server-authoritative department duty state
-- ==========================================================================
-- Tracks whether a player is on duty and for which department (BCSO/FHP/MPD).
-- SERVER-AUTHORITATIVE: a duty change is only honoured if the player actually
-- holds the matching department role (verified via flrp_permissions). A client
-- can never spoof itself onto a department. Department pay in flrp_economy is
-- driven by this state. See docs/DEPARTMENTS.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_duty'
author 'Florida Roleplay (FLRP)'
description 'FLRP server-authoritative duty state for BCSO/FHP/MPD'
version '0.1.0'

dependency 'flrp_core'

server_scripts {
  'server/duty.lua',
  'server/exports.lua',
  'server/main.lua',
}

server_exports {
  'GetDuty',
  'IsOnDuty',
  'SetDuty',
  'GoOffDuty',
}
