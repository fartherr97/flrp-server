-- ==========================================================================
-- FLRP :: flrp_messages/config.lua — in-game private messages (PM/DM)
-- ==========================================================================
-- A player-to-player direct-message system with a jail-styled panel:
--   * /pm                 -> open the Messages panel
--   * /pm <id> <message>  -> quick-send without opening the panel
--   * <keybind>           -> open the panel (rebind in Settings > Key Bindings)
-- Staff (MonitorAce) get a live "Monitor" tab that mirrors EVERY private
-- message on the server, and every PM is also logged to Discord (#…-logs,
-- flrp_logs category `pm`). History is session-only (kept in memory).
-- ==========================================================================

FLRP_MESSAGES = {}

FLRP_MESSAGES.Command    = 'pm'                  -- /pm (open) and /pm <id> <msg> (quick send)
FLRP_MESSAGES.AltCommand = 'messages'            -- also opens the panel
FLRP_MESSAGES.Key        = ''                    -- default open keybind ('' = unbound)
FLRP_MESSAGES.MonitorAce = 'flrp.staff.moderate' -- who sees the live monitor of all PMs
FLRP_MESSAGES.MaxLength  = 300                   -- characters per message
FLRP_MESSAGES.MaxHistory = 600                   -- messages kept in memory (session)
FLRP_MESSAGES.LogWebhook = true                  -- mirror every PM to the `pm` webhook
