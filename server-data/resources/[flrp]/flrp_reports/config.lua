-- ==========================================================================
-- FLRP :: flrp_reports/config.lua — staff report system
-- ==========================================================================
-- Players: /report or /calladmin (or press J) -> submit a report, track it,
--          read + reply to staff messages.
-- Staff:   press J -> console: live queue, claim, message the player, goto /
--          bring, resolve, analytics leaderboard (claim + resolve times).
-- A toast pops for staff on every new report; pressing J while it's showing
-- opens that report directly.
-- ==========================================================================

FLRP_REPORTS = {}

FLRP_REPORTS.Key            = 'J'                       -- RegisterKeyMapping default (players can rebind)
FLRP_REPORTS.StaffAce       = 'flrp.staff.moderate'     -- who gets the staff console
FLRP_REPORTS.SelfClaimAce   = 'flrp.staff.direct'       -- may claim/resolve their OWN reports (director+; ownership inherits)
FLRP_REPORTS.Commands       = { 'report', 'calladmin' } -- both open the player form

-- Logo shown in the menu header (convar `flrp_reports_logo` overrides).
FLRP_REPORTS.Logo           = 'https://www.flrp.us/images/c8452f76261f8e9c.png'
FLRP_REPORTS.ServerName     = 'Florida Roleplay'

FLRP_REPORTS.Categories = {
  { id = 'player',  label = 'Player Report',     colour = '#ff6b6b' },
  { id = 'cheat',   label = 'Cheating / Exploit', colour = '#ff4d4d' },
  { id = 'bug',     label = 'Bug',               colour = '#f5b342' },
  { id = 'question',label = 'Question',          colour = '#00bfc4' },
  { id = 'refund',  label = 'Refund',            colour = '#a78bfa' },
  { id = 'other',   label = 'Other',             colour = '#9aa7b2' },
}

-- Anti-spam
FLRP_REPORTS.CooldownSeconds  = 60     -- between submissions per player
FLRP_REPORTS.MaxOpenPerPlayer = 3      -- open/claimed reports a player may have at once
FLRP_REPORTS.MaxDescription   = 600
FLRP_REPORTS.MaxMessage       = 400

-- How long the staff "new report" toast stays (and how long J will jump to it)
FLRP_REPORTS.ToastSeconds     = 12

-- Analytics: a staffer needs at least this many claims to rank on the
-- "fastest responder" board (stops one lucky claim topping the chart).
FLRP_REPORTS.MinClaimsToRank  = 3
-- How many resolved reports to keep showing in the staff "Resolved" tab.
FLRP_REPORTS.ResolvedHistory  = 30

-- Return destinations for a summoned player after a sit. `previous` is always
-- offered first (the exact spot they were Brought from). The rest are presets
-- staff can pick from the Return selector; coords are standard GTA V map spots.
FLRP_REPORTS.ReturnLocations = {
  { id = 'legion', label = 'Legion Square', x = 195.0,  y = -933.6,  z = 30.7, h = 144.0 },
  { id = 'mrpd',   label = 'MRPD',          x = 441.0,  y = -982.0,  z = 30.7, h = 90.0  },
  { id = 'pillbox',label = 'Pillbox Hospital', x = 298.6, y = -584.4, z = 43.3, h = 70.0 },
  { id = 'airport',label = 'LSIA',          x = -1037.7,y = -2737.6, z = 20.2, h = 330.0 },
  { id = 'paleto', label = 'Paleto Bay',    x = -448.0, y = 6012.0,  z = 31.7, h = 45.0  },
  { id = 'sandy',  label = 'Sandy Shores',  x = 1853.2, y = 3689.5,  z = 34.3, h = 210.0 },
}

-- Discord: sends via flrp_logs category `report` (set flrp_log_webhook_report
-- in secrets.cfg). Silent if not configured.
FLRP_REPORTS.DiscordLog       = true
-- Discord role to PING (above the embed) on every NEW report. The real id is
-- read from this convar — set it in secrets.cfg, e.g.
--   set flrp_reports_ping_role "123456789012345678"   (your Staff Team role id)
-- Leave unset / REPLACE_ME and the line is posted without a ping.
FLRP_REPORTS.PingRoleConvar   = 'flrp_reports_ping_role'
