-- ==========================================================================
-- FLRP :: flrp_death/config.lua — death timer, respawn & revive
-- ==========================================================================
-- On death everyone EXCEPT staff (flrp.staff.moderate; directors/ownership
-- inherit) gets a 60s red countdown before they can press a key to respawn.
-- /revive lets anyone revive a downed player, but a non-staff reviver must wait
-- out the target's timer; staff bypass it. No voice while dead.
-- ==========================================================================

FLRP_DEATH = {}

FLRP_DEATH.BypassAce    = 'flrp.staff.moderate'  -- no timer + revive-anytime (staff/dir/owner)
FLRP_DEATH.WaitSeconds  = 60                      -- respawn/revive lock for regular players
FLRP_DEATH.RespawnKey   = 'E'                     -- default (rebindable in Settings)
FLRP_DEATH.ReviveReach  = 3.5                     -- metres a reviver must be within
FLRP_DEATH.RespawnHealth= 200                     -- health on respawn/revive (200 = full)

-- Respawn destinations — player respawns at the NEAREST of these to where they
-- died. vector4(x, y, z, heading). Defaults are LS/Blaine hospitals.
FLRP_DEATH.Hospitals = {
  vector4(298.98,  -584.45, 43.26, 70.0),   -- Pillbox Hill, Los Santos
  vector4(-247.60, 6331.40, 32.43, 220.0),  -- Paleto Bay medical
  vector4(1839.60, 3672.90, 34.28, 210.0),  -- Sandy Shores medical
}

-- On-screen copy
FLRP_DEATH.DeadText     = 'You are DEAD — you cannot speak in voice chat while dead.'
FLRP_DEATH.LockedText   = 'RESPAWN LOCKED'
FLRP_DEATH.RespawnText  = 'Press [%s] to respawn'
