-- ==========================================================================
-- FLRP :: flrp_vmenulog/config.lua — log vMenu actions to Discord
-- ==========================================================================
-- vMenu is escrowed/standalone, so we don't edit it — we piggyback:
--   TIME / WEATHER : vMenu syncs these by triggering server events; we listen
--                    on the same event names and log who changed what.
--   REPAIR         : vMenu's "Fix Vehicle" is client-only with no event, so we
--                    watch the driver's vehicle for an instant full repair.
-- Logs go to flrp_logs categories `timeweather` and `repair`.
-- ==========================================================================

FLRP_VMENULOG = {}

-- vMenu's synced weather/time server events. If your vMenu fork renames them,
-- flip Debug on to print what actually arrives, then update these.
FLRP_VMENULOG.WeatherEvent = 'vMenu:UpdateServerWeather'   -- (newWeather, blackout, dynamic)
FLRP_VMENULOG.TimeEvent    = 'vMenu:UpdateServerTime'      -- (hours, minutes, freeze)

FLRP_VMENULOG.Repair = {
  Enabled   = true,
  PollMs    = 350,      -- how often to sample engine/body health
  JumpMin   = 120.0,    -- a health rise this big in one sample = a repair
  FullAbove = 950.0,    -- ...and it must finish at/above near-full health
  Cooldown  = 4000,     -- ms between repair logs per player (anti-spam)
}

FLRP_VMENULOG.Debug = false   -- print received time/weather event args to console
