-- ==========================================================================
-- FLRP :: flrp_duty/shared/config.lua
-- ==========================================================================
-- Maps flrp_onduty DEPARTMENT IDs to FLRP departments. These are the `id`
-- values in flrp_onduty/config.lua Departments. Set these to match whatever you
-- name the BSO / FHP / MPD departments there.
--
-- Defaults assume you name them `bso`, `fhp`, `mpd`. If you use different IDs,
-- either edit here or override per-department with a convar:
--   set flrp_duty_entity_bso "myBsoEntityId"
--   set flrp_duty_entity_fhp  "myFhpEntityId"
--   set flrp_duty_entity_mpd  "myMpdEntityId"
-- Only these three FLRP departments pay department wages; any other
-- entity (e.g. a "staff" dual-duty entity) is ignored for department pay.
-- ==========================================================================

FLRPD = FLRPD or {}
FLRPD.Config = {}

-- department id (lowercase) -> FLRP department (UPPER). Filled at runtime
-- from convars with these defaults.
FLRPD.Config.DefaultEntityMap = {
  bso = 'BSO',
  fhp  = 'FHP',
  mpd  = 'MPD',
}

-- Seconds to cache a player's duty lookup (avoids querying every pay tick).
FLRPD.Config.CacheTtlSeconds = 15
