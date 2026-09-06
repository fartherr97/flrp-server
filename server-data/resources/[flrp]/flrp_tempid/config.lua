-- ==========================================================================
-- FLRP :: flrp_tempid/config.lua — LEO "Temp ID" reveal
-- ==========================================================================
-- A sworn officer presses the keybind (or /tempid) and, for a few seconds,
-- every nearby player's SERVER ID floats above their head — only on the
-- officer's screen. Server-authoritative: the client only shows IDs after the
-- server confirms the requester is LEO, and each use is logged to Discord
-- (#temp-id-logs, category `tempid`).
-- ==========================================================================

FLRP_TEMPID = {}

FLRP_TEMPID.Ace      = 'flrp.leo'   -- who may use it (server-checked)
FLRP_TEMPID.Command  = 'tempid'     -- /tempid, and the rebindable keybind name
FLRP_TEMPID.Key      = ''           -- default key ('' = unbound; players bind in Settings > Key Bindings)
FLRP_TEMPID.Duration = 5000         -- ms the IDs stay visible
FLRP_TEMPID.Range    = 30.0         -- metres — only players within this show an ID
FLRP_TEMPID.Cooldown = 2000         -- ms between uses (anti-spam)
FLRP_TEMPID.Label    = 'ID'         -- prefix, e.g. "ID 42"
