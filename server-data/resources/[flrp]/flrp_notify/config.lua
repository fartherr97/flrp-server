-- ==========================================================================
-- FLRP :: flrp_notify/config.lua — join / leave toast settings
-- ==========================================================================
-- A small nex-styled toast slides in at the top-center of the screen when a
-- player joins or leaves. Replaces the native vMenu "X joined the server" chat
-- line (deny vMenu.MiscSettings.JoinQuitNotifs in permissions.cfg so they don't
-- double up). Tune timing/colours/wording here; tune POSITION in html/style.css
-- (the #toasts block — it's marked "nudge to move").
-- ==========================================================================

FLRP_NOTIFY = {}

FLRP_NOTIFY.DurationMs = 5000          -- how long each toast stays before fading
FLRP_NOTIFY.MaxVisible = 4             -- most toasts stacked at once (oldest drops)

FLRP_NOTIFY.JoinColor  = '#35d07f'     -- accent bar for a join  (matches on-duty green)
FLRP_NOTIFY.LeaveColor = '#ff4d4d'     -- accent bar for a leave (matches on-duty red)

FLRP_NOTIFY.JoinText   = 'joined the server'
FLRP_NOTIFY.LeaveText  = 'left the server'
