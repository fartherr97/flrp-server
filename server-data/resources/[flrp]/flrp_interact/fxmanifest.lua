-- ==========================================================================
-- FLRP :: flrp_interact — the "M" interaction menu (SSRP-style, vMenu look)
-- ==========================================================================
-- A native-drawn interaction menu (keybind M): Civilian/LEO toolboxes, donator
-- vehicle spawns (from the flrp_vehicles registry), and civilian + LEO dept
-- advertisements to the chat box. Categories are config-driven and ACE-gated
-- server-side. No NUI/CEF — drawn with GTA natives so it matches vMenu.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_interact'
author 'Florida Roleplay (FLRP)'
description 'FLRP interaction menu (M): toolboxes, donator vehicles, advertisements'
version '0.1.0'

shared_script 'config.lua'

client_scripts {
  'client/menu.lua',
  'client/main.lua',
}

server_scripts {
  'server/main.lua',
}

-- Runtime export deps (soft): flrp_vehicles (donator spawns), flrp_logs (advert
-- logging), flrp_notify (toasts). Menu still works if any are absent.
