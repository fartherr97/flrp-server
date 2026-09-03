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

-- Discord roster (authoritative). The tracker lists EVERY guild member holding
-- one of these roles, whether or not they've ever joined the server — and ONLY
-- these roles. Ordered highest -> lowest; a member is placed in the FIRST tier
-- whose role they hold (so a Dept Head who is also an Admin shows under
-- Administrators, and a pure Dept Head shows under Auxiliary Staff at the
-- bottom). Needs the bot's "Server Members Intent" (the connection gate needs
-- it too). If Discord can't be reached it falls back to staff who have
-- connected (grouped by their ACE rank under FLRP_STAFF.Ranks).
FLRP_STAFF.RankTiers = {
  { label = 'Staff Directors',       ids = { '1535994200808497162', '1542221076216676422' } }, -- Staff Director + Asst. Staff Director
  { label = 'Lead Administrators',   ids = { '1534709718797258882' } },
  { label = 'Senior Administrators', ids = { '1534709852272857270' } },
  { label = 'Administrators',        ids = { '1534709892420599930' } },
  { label = 'Junior Administrators', ids = { '1535994725797199972' } },
  { label = 'Senior Moderators',     ids = { '1535994898283495434' } },
  { label = 'Moderators',            ids = { '1534910970009354261' } },
  { label = 'Trial Moderators',      ids = { '1534911043426451466' } },
  -- Dept Head -> listed below Trial Moderators as Auxiliary Staff (lowest tier)
  { label = 'Auxiliary Staff',       ids = { '1534380750173110282' } },
}
