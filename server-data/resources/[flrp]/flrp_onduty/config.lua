-- ==========================================================================
-- FLRP :: flrp_onduty/config.lua — departments, ranks, access, loadouts
-- ==========================================================================
-- /duty (or the key below) opens the duty menu. A player sees only the
-- departments + ranks their ACE aces allow:
--   * Patrol      -> flrp.dept.<id>            (every dept member has this today)
--   * Supervisor  -> flrp.rank.<id>.supervisor (grant to a dept-supervisor group)
--   * Command     -> flrp.rank.<id>.command    (grant to a dept-command group)
--   * OverrideAce -> every department, every rank (Directors; Ownership inherits)
-- The live roster is written to `flrp_duty_members`, which flrp_duty (and so
-- the HUD counter, LEO blips, status embed, department pay and the staff
-- tracker) already read. Staff vest/duty is separate: /vest (flrp_staffactivity).
-- ==========================================================================

FLRP_ONDUTY = {}

FLRP_ONDUTY.Command      = 'duty'
FLRP_ONDUTY.Key          = 'F6'        -- RegisterKeyMapping default; players can rebind
FLRP_ONDUTY.OverrideAce  = 'flrp.staff.direct'
FLRP_ONDUTY.ForceOffAce  = 'flrp.staff.administer'   -- /offduty <id>
-- Who may see the Units board (/duty units): any of these aces. LEO + staff.
FLRP_ONDUTY.UnitsAces    = { 'flrp.leo', 'flrp.staff.moderate' }
FLRP_ONDUTY.Logo         = 'https://www.flrp.us/images/c8452f76261f8e9c.png'
FLRP_ONDUTY.ServerName   = 'Florida Roleplay'

FLRP_ONDUTY.CallsignMax  = 8
FLRP_ONDUTY.RemoveWeaponsOffDuty = true   -- strip the loadout when going off duty

FLRP_ONDUTY.Departments = {
  { id = 'bso', label = "Broward Sheriff's Office",  short = 'BSO', colour = '#e0b341', requireCallsign = true, loadout = 'police',
    ranks = { { id = 'patrol', label = 'Patrol', ace = 'flrp.dept.bso' },
              { id = 'supervisor', label = 'Supervisor', ace = 'flrp.rank.bso.supervisor' },
              { id = 'command', label = 'Command', ace = 'flrp.rank.bso.command' } } },
  { id = 'fhp', label = 'Florida Highway Patrol',    short = 'FHP', colour = '#c9852b', requireCallsign = true, loadout = 'police',
    ranks = { { id = 'patrol', label = 'Patrol', ace = 'flrp.dept.fhp' },
              { id = 'supervisor', label = 'Supervisor', ace = 'flrp.rank.fhp.supervisor' },
              { id = 'command', label = 'Command', ace = 'flrp.rank.fhp.command' } } },
  { id = 'mpd', label = 'Miami Police Department',   short = 'MPD', colour = '#3b82f6', requireCallsign = true, loadout = 'police',
    ranks = { { id = 'patrol', label = 'Patrol', ace = 'flrp.dept.mpd' },
              { id = 'supervisor', label = 'Supervisor', ace = 'flrp.rank.mpd.supervisor' },
              { id = 'command', label = 'Command', ace = 'flrp.rank.mpd.command' } } },
}

-- Weapons handed out on duty (applied client-side; removed on off-duty).
FLRP_ONDUTY.Loadouts = {
  police = {
    { name = 'WEAPON_FLASHLIGHT' },
    { name = 'WEAPON_NIGHTSTICK' },
    { name = 'WEAPON_STUNGUN' },
    { name = 'WEAPON_COMBATPISTOL', ammo = 72,  attachments = { 'COMPONENT_AT_PI_FLSH' } },
    { name = 'WEAPON_PUMPSHOTGUN',  ammo = 16 },
    { name = 'WEAPON_CARBINERIFLE', ammo = 90,  attachments = { 'COMPONENT_AT_AR_FLSH' } },
  },
}
