-- ==========================================================================
-- FLRP :: flrp_fullauto/config.lua — restrict fully-automatic fire
-- ==========================================================================
-- Fully-automatic fire is OFF for everyone by default. Anyone WITHOUT the
-- `flrp.fullauto` ACE is limited to semi-auto (one shot per trigger pull) on
-- every weapon; holding the trigger no longer sprays.
--
-- Who keeps full-auto (granted in config/permissions.cfg):
--   • Ownership + Director  (add_ace group.flrp.director flrp.fullauto)
--   • the SWAT Permission role -> group.flrp.swat (mapped via flrp_role_swat)
--
-- Server-authoritative: the client only unlocks full-auto after the server
-- confirms the ACE, and re-checks periodically so role changes take effect.
-- ==========================================================================

FLRP_FULLAUTO = {}

FLRP_FULLAUTO.Ace           = 'flrp.fullauto'  -- who may fire full-auto
FLRP_FULLAUTO.RecheckSeconds = 60              -- re-verify access on a timer (role changes)
