-- ==========================================================================
-- FLRP :: flrp_duty/shared/config.lua
-- ==========================================================================
-- Maps nex-duty ENTITY IDs to FLRP departments. nex-duty entity IDs are the
-- `id` you set for each entity in nex-duty's config (used in its ace perms,
-- e.g. `nex-duty.<entity>.<rank>`). Set these to match whatever you name the
-- BCSO / FHP / MPD entities in nex-duty.
--
-- Defaults assume you name them `bcso`, `fhp`, `mpd`. If you use different IDs,
-- either edit here or override per-department with a convar:
--   set flrp_duty_entity_bcso "myBcsoEntityId"
--   set flrp_duty_entity_fhp  "myFhpEntityId"
--   set flrp_duty_entity_mpd  "myMpdEntityId"
-- Only these three FLRP departments pay department wages; any other nex-duty
-- entity (e.g. a "staff" dual-duty entity) is ignored for department pay.
-- ==========================================================================

FLRPD = FLRPD or {}
FLRPD.Config = {}

-- nex-duty entity id (lowercase) -> FLRP department (UPPER). Filled at runtime
-- from convars with these defaults.
FLRPD.Config.DefaultEntityMap = {
  bcso = 'BCSO',
  fhp  = 'FHP',
  mpd  = 'MPD',
}

-- Seconds to cache a player's duty lookup (avoids querying every pay tick).
FLRPD.Config.CacheTtlSeconds = 15
