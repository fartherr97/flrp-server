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

-- Auto-post cadence. AutoPost=true posts the tracker automatically every
-- PeriodDays (like SSRP's fortnightly report). The manual command can post any
-- range at any time without affecting the auto schedule.
FLRP_STAFF.AutoPost   = true
FLRP_STAFF.PeriodDays = 14

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
