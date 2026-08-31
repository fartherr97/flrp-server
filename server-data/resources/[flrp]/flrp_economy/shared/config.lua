-- ==========================================================================
-- FLRP :: flrp_economy/shared/config.lua
-- ==========================================================================
FLRPE = FLRPE or {}
FLRPE.Config = {}

-- Client activity heartbeat cadence (ms). The CLIENT only sends a heartbeat
-- when the player has produced control input recently, so a truly-AFK player
-- stops heartbeating. The SERVER still bounds "active" by GetPlayerLastMsg, so
-- a spoofed heartbeat cannot manufacture pay while genuinely idle.
FLRPE.Config.HeartbeatIntervalMs = 30000

-- Client considers the player "moving/active" if a relevant control was used
-- within this window (ms).
FLRPE.Config.ClientActivityWindowMs = 60000
