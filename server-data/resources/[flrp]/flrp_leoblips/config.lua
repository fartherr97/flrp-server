-- ==========================================================================
-- FLRP :: flrp_leoblips/config.lua — on-duty LEO map blips
-- ==========================================================================
-- Every UpdateMs the server reads the live on-duty roster (flrp_onduty's
-- flrp_duty_members via flrp_duty) and pushes each on-duty officer's position to
-- the players allowed to see them. Clients draw one blip per officer, coloured
-- by department, labelled "CALLSIGN | Name". Your own blip is never drawn.
-- ==========================================================================

FLRP_BLIPS = {}

FLRP_BLIPS.UpdateMs = 2000          -- position refresh cadence (ms)

-- Who may SEE the blips: any on-duty LEO, plus anyone holding this ace.
FLRP_BLIPS.StaffAce = 'flrp.staff.moderate'

-- department id -> blip colour. These are GTA blip colour indices and
-- match the department colours in flrp_onduty/config.lua so the
-- map matches the duty menu:  BSO gold, FHP dark orange / tan, MPD blue.
FLRP_BLIPS.Colours = {
  bso = 46,
  fhp = 47,
  mpd = 3,
}
FLRP_BLIPS.DefaultColour = 0       -- white, for any entity not listed above

FLRP_BLIPS.Sprite     = 1          -- standard round blip
FLRP_BLIPS.Scale      = 0.85
FLRP_BLIPS.ShortRange = false      -- false = visible across the whole map
