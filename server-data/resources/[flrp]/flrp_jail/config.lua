-- ==========================================================================
-- FLRP :: flrp_jail/config.lua — Jail Manager + Hospitalize
-- ==========================================================================
-- Staff open the Jail Manager (/jail) to jail (red) or hospitalize (green) a
-- player; LEO get a blue "LEO Hospitalize" (2m) for downing other LEO. Jail
-- confines the target to a cell for N seconds and persists across relogs.
-- Hospitalize sends them to a chosen hospital and keeps them injured for the
-- duration. All privileged actions are re-checked server-side.
-- ==========================================================================

FLRP_JAIL = {}

-- ---- access --------------------------------------------------------------
FLRP_JAIL.StaffAce   = 'flrp.staff.moderate'  -- open manager + Jail + Hospitalize
FLRP_JAIL.LeoAce     = 'flrp.leo'             -- open manager + LEO Hospitalize (LEO-on-LEO)
FLRP_JAIL.Commands   = { 'jail' }

-- ---- limits --------------------------------------------------------------
FLRP_JAIL.MaxSeconds        = 1800   -- max jail seconds a staffer can enter (30m)
FLRP_JAIL.DefaultSeconds    = 60     -- default value in the seconds box
FLRP_JAIL.LeoHospSeconds    = 120    -- blue LEO Hospitalize = 2 minutes (fixed)
FLRP_JAIL.LeoHospTargetLeo  = true   -- LEO Hospitalize only works on other LEO (staff bypass)

-- Hospitalize injury types -> downtime. Staff pick the injury; its time is used.
-- Reasonable defaults (tune freely). LEO Hospitalize ignores these (fixed 2m).
FLRP_JAIL.Injuries = {
  { id = 'minor',      label = 'Minor Injury',        seconds = 120 },  -- 2m
  { id = 'moderate',   label = 'Moderate Injury',     seconds = 240 },  -- 4m
  { id = 'laceration', label = 'Deep Laceration',     seconds = 300 },  -- 5m
  { id = 'fracture',   label = 'Broken Bone',         seconds = 300 },  -- 5m
  { id = 'blunt',      label = 'Blunt Force Trauma',  seconds = 300 },  -- 5m
  { id = 'mvc',        label = 'Vehicle Collision',   seconds = 360 },  -- 6m
  { id = 'stab',       label = 'Stab Wound',          seconds = 360 },  -- 6m
  { id = 'overdose',   label = 'Overdose',            seconds = 240 },  -- 4m
  { id = 'burn',       label = 'Burns',               seconds = 420 },  -- 7m
  { id = 'gsw',        label = 'Gunshot Wound',       seconds = 420 },  -- 7m
  { id = 'critical',   label = 'Critical / Multiple', seconds = 600 },  -- 10m
}
FLRP_JAIL.DefaultInjury = 'moderate'

-- ---- locations -----------------------------------------------------------
-- Jail cell (target is teleported here and kept within CellRadius of it).
-- >>> Replace with your jail MLO cell coords. Default = Bolingbroke yard. <<<
FLRP_JAIL.Cell        = vector4(1845.13, 2585.87, 45.67, 270.0)
FLRP_JAIL.CellRadius  = 22.0                         -- metres they may roam from the cell
FLRP_JAIL.Release     = vector4(1850.09, 2605.36, 45.67, 45.0)  -- released here when time is up

-- Hospitals for the Hospitalize dropdown (name shown in the selector).
-- >>> Confirm/adjust coords for your map. <<<
FLRP_JAIL.Hospitals = {
  { id = 'pillbox', label = 'Pillbox Hill (LS)',   coords = vector4(298.98, -584.45, 43.26, 70.0) },
  { id = 'zonah',   label = 'Mount Zonah (LS)',    coords = vector4(-449.9, -340.9, 34.5, 78.0) },
  { id = 'sandy',   label = 'Sandy Shores',        coords = vector4(1839.6, 3672.9, 34.28, 210.0) },
  { id = 'paleto',  label = 'Paleto Bay',          coords = vector4(-247.6, 6331.4, 32.43, 220.0) },
}

-- ---- penal code (charge -> jail time) ------------------------------------
-- Charges + jail times load from penalcode.json in this resource (seeded with a
-- reasonable STARTER set — replace with your real penal code). Selecting charges
-- in the Jail Manager adds their time to the seconds box.
--
-- OPTIONAL live sync: point this convar (in secrets.cfg) at a JSON endpoint that
-- returns the SAME shape as penalcode.json ({ "charges":[{id,name,class,
-- jailSeconds,fine}] }). The SERVER fetches it on start and overrides the file.
--   set flrp_penalcode_url "https://www.flrp.us/api/penalcode"
FLRP_JAIL.PenalCodeConvar = 'flrp_penalcode_url'

-- ---- branding ------------------------------------------------------------
FLRP_JAIL.Logo       = 'https://www.flrp.us/images/c8452f76261f8e9c.png'  -- convar flrp_reports_logo overrides
FLRP_JAIL.ServerName = 'Florida Roleplay'
FLRP_JAIL.Key        = ''   -- optional keybind to open (blank = command only)
