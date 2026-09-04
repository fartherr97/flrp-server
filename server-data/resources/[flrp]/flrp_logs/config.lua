-- ==========================================================================
-- FLRP :: flrp_logs/config.lua — log categories -> Discord webhooks
-- ==========================================================================
-- Each category reads its webhook URL from a convar set in secrets.cfg (never
-- committed — webhook URLs are credentials). A category with no/blank convar is
-- silently skipped, so you can enable channels one at a time.
--
-- In secrets.cfg (gitignored), for each channel you want:
--   set flrp_log_webhook_<category> "https://discord.com/api/webhooks/xxx/yyy"
-- ==========================================================================

FLRP_LOGS = {}

-- Bot identity on the webhook messages.
FLRP_LOGS.Username = 'FLRP In-Game Logs'
FLRP_LOGS.Avatar   = '' -- optional icon URL

-- category = { convar, color (embed bar), title (default event label) }
-- Colors are 0xRRGGBB. Add rows as you create the matching Discord channel +
-- webhook and set its convar.
FLRP_LOGS.Categories = {
  -- ---- wired and working today ----
  join      = { convar = 'flrp_log_webhook_join',      color = 0x2ecc71, title = 'PLAYER JOINED' },
  leave     = { convar = 'flrp_log_webhook_leave',     color = 0xe74c3c, title = 'PLAYER LEFT' },
  chat      = { convar = 'flrp_log_webhook_chat',      color = 0x95a5a6, title = 'CHAT' },
  staffchat = { convar = 'flrp_log_webhook_staffchat', color = 0xff1717, title = 'COMMAND RAN' },
  death     = { convar = 'flrp_log_webhook_death',     color = 0xc0392b, title = 'DEATH' },

  -- ---- ready to receive, wire from the owning feature when built ----
  -- Call: exports.flrp_logs:Send('<category>', { player = src, description = '...' })
  money     = { convar = 'flrp_log_webhook_money',     color = 0xf1c40f, title = 'MONEY' },
  taser     = { convar = 'flrp_log_webhook_taser',     color = 0xf39c12, title = 'TASER' },
  jail      = { convar = 'flrp_log_webhook_jail',      color = 0x8e44ad, title = 'JAIL' },        -- #staff-jail-logs
  hospital  = { convar = 'flrp_log_webhook_hospital',  color = 0xe67e22, title = 'HOSPITALIZE' }, -- #jail-hospital-logs
  revive    = { convar = 'flrp_log_webhook_revive',    color = 0x2ecc71, title = 'REVIVE' },
  vest      = { convar = 'flrp_log_webhook_vest',      color = 0x3498db, title = 'STAFF VEST' },
  namechange= { convar = 'flrp_log_webhook_namechange',color = 0x95a5a6, title = 'NAME CHANGE' },
  aop       = { convar = 'flrp_log_webhook_aop',       color = 0x1abc9c, title = 'AOP CHANGE' },
  report    = { convar = 'flrp_log_webhook_report',    color = 0x00bfc4, title = 'REPORT' },
  blocked   = { convar = 'flrp_log_webhook_blocked',   color = 0xe74c3c, title = 'BLOCKED CONNECTION' },

  -- ---- channels awaiting an owning feature (convars ready; nothing sends yet) ----
  damage      = { convar = 'flrp_log_webhook_damage',      color = 0xc0392b, title = 'DAMAGE' },
  chatfilter  = { convar = 'flrp_log_webhook_chatfilter',  color = 0x95a5a6, title = 'CHAT FILTER' },
  winch       = { convar = 'flrp_log_webhook_winch',       color = 0x7f8c8d, title = 'WINCH' },
  staffblip   = { convar = 'flrp_log_webhook_staffblip',   color = 0x3498db, title = 'STAFF BLIP' },
  personalveh = { convar = 'flrp_log_webhook_personalveh', color = 0x1abc9c, title = 'PERSONAL VEHICLE' },
  menu        = { convar = 'flrp_log_webhook_menu',        color = 0x9b59b6, title = 'MENU' },
  undercover  = { convar = 'flrp_log_webhook_undercover',  color = 0x34495e, title = 'UNDERCOVER' },
  thermal     = { convar = 'flrp_log_webhook_thermal',     color = 0xe67e22, title = 'THERMAL' },
  spectate    = { convar = 'flrp_log_webhook_spectate',    color = 0x9b59b6, title = 'SPECTATE' },
  tempid      = { convar = 'flrp_log_webhook_tempid',      color = 0x95a5a6, title = 'TEMP ID' },
  grab        = { convar = 'flrp_log_webhook_grab',        color = 0xe67e22, title = 'GRAB / CARRY' },
  trucker     = { convar = 'flrp_log_webhook_trucker',     color = 0xf1c40f, title = 'TRUCKER' },
  timeweather = { convar = 'flrp_log_webhook_timeweather', color = 0x3498db, title = 'TIME / WEATHER' },
  music       = { convar = 'flrp_log_webhook_music',       color = 0x9b59b6, title = 'MUSIC' },
  repair      = { convar = 'flrp_log_webhook_repair',      color = 0x1abc9c, title = 'REPAIR' },
  hitch       = { convar = 'flrp_log_webhook_hitch',       color = 0x7f8c8d, title = 'HITCH / TOW' },
}

-- Rank labels, highest first (used in the "[id] pid | rank | name" footer).
FLRP_LOGS.Ranks = {
  { ace = 'flrp.staff.own',        label = 'Ownership' },
  { ace = 'flrp.staff.direct',     label = 'Director' },
  { ace = 'flrp.staff.administer', label = 'Admin' },
  { ace = 'flrp.staff.moderate',   label = 'Mod' },
  { ace = 'flrp.dept.bso',         label = 'BSO' },
  { ace = 'flrp.dept.fhp',         label = 'FHP' },
  { ace = 'flrp.dept.mpd',         label = 'MPD' },
}
