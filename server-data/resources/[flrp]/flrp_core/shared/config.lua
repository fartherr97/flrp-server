-- ==========================================================================
-- FLRP :: flrp_core/shared/config.lua
-- ==========================================================================
-- Static, code-level defaults for flrp_core. Runtime-tunable values come from
-- convars (config/*.cfg) and the DB `configuration` table via
-- exports.flrp_core:GetConfig(). This file only holds things that rarely
-- change and are safe on both client and server.
-- ==========================================================================

FLRP = FLRP or {}
FLRP.Config = FLRP.Config or {}

-- Log verbosity: 'debug' | 'info' | 'warn' | 'error'
-- Read from a convar so it's tunable without a code change. Default 'warn'
-- keeps the console quiet (hides the per-reconcile store-loaded / config-
-- re-applied INFO lines). For verbose debugging: `setr flrp_log_level info`
-- (or 'debug') in server.cfg, then restart flrp_core.
FLRP.Config.LogLevel = GetConvar('flrp_log_level', 'warn')

-- How often (ms) the player-cache housekeeping tick runs.
FLRP.Config.CacheTickMs = 60000

-- Convar names flrp_core reads (documented for reference).
FLRP.Config.Convars = {
  DatabaseConnection = 'flrp_database_connection', -- optional alias; oxmysql uses mysql_connection_string
}
