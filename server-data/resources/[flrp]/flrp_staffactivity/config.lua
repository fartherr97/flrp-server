-- ==========================================================================
-- FLRP :: flrp_staffactivity/config.lua
-- ==========================================================================
-- Tracks two things per staff member and posts them to a Discord webhook the
-- way SSRP's "Staff Activity Tracker" does:
--   * CLAIMS  — report claims (from flrp_reports' `reports` table)
--   * VEST     — time spent wearing the staff vest / on staff duty
--
-- Vest time is driven by the /vest toggle (and /sd alias). The future EUP
-- staff-vest system can drive the exact same state with:
--   exports.flrp_staffactivity:SetVest(src, true|false)
--
-- Set the webhook in secrets.cfg:
--   set flrp_staff_activity_webhook "https://discord.com/api/webhooks/xxx/yyy"
-- ==========================================================================

FLRP_STAFF = {}

FLRP_STAFF.WebhookConvar = 'flrp_staff_activity_webhook'
FLRP_STAFF.ServerName    = 'Florida Roleplay'
FLRP_STAFF.Username      = 'FLRP Staff Activity'
FLRP_STAFF.Logo          = 'https://www.flrp.us/images/c8452f76261f8e9c.png' -- convar flrp_reports_logo also honoured
FLRP_STAFF.Colour        = 0x00bfc4

-- Who may toggle vest (staff), and who may post the tracker on demand.
FLRP_STAFF.VestAce   = 'flrp.staff.moderate'   -- /vest, /sd
FLRP_STAFF.ManageAce = 'flrp.staff.direct'     -- /staffactivity [days]

-- Cycle. Fixed 14-day windows anchored at CycleStart (UTC midnight). ONE live
-- embed per cycle is posted and then EDITED in place every RefreshMinutes so
-- it always shows the current window (e.g. "September 03 - September 17").
-- When a cycle ends it's stamped "Final" (archived) and a fresh embed begins
-- the next cycle. /staffactivity last re-posts the previous, completed cycle.
FLRP_STAFF.CycleStart     = { year = 2026, month = 9, day = 3 }
FLRP_STAFF.CycleDays      = 14
FLRP_STAFF.RefreshMinutes = 15

-- Staff ranks, highest first: ACE that identifies the rank, the label used in
-- the roster, and the group heading it appears under in the embed. Grouping +
-- ordering follow this list.
FLRP_STAFF.Ranks = {
  { ace = 'flrp.staff.own',        label = 'Ownership',     group = 'Ownership' },
  { ace = 'flrp.staff.direct',     label = 'Director',      group = 'Directors' },
  { ace = 'flrp.staff.administer', label = 'Administrator', group = 'Administrators' },
  { ace = 'flrp.staff.moderate',   label = 'Moderator',     group = 'Moderators' },
}
FLRP_STAFF.UnknownGroup = 'Staff'   -- claimers we have no captured rank for

-- Discord roster (authoritative). The tracker lists EVERY member of the guild
-- holding one of these roles, whether or not they've ever joined the server.
-- Role ids come from the same secrets.cfg convars the connection gate uses.
-- Highest first. Needs the bot's "Server Members Intent" (the gate needs it too).
-- If Discord can't be reached, it falls back to staff who have connected.
FLRP_STAFF.RankRoles = {
  { convar = 'flrp_role_ownership',     label = 'Ownership' },
  { convar = 'flrp_role_director',      label = 'Director' },
  { convar = 'flrp_role_administrator', label = 'Administrator' },
  { convar = 'flrp_role_moderator',     label = 'Moderator' },
}
