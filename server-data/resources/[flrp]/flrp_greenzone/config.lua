-- ==========================================================================
-- FLRP :: flrp_greenzone/config.lua — safe zones (green zones)
-- ==========================================================================
-- Ownership opens /greenzones to create circular safe zones in-game and toggle
-- what each one blocks (weapons / damage / vehicles). Zones persist in the DB
-- and sync live to every client, which enforces the options and shows a notice
-- on entry/exit. Zones are marked on the map with a green radius blip.
-- ==========================================================================

FLRP_GZ = {}

FLRP_GZ.ManageAce = 'flrp.staff.own'   -- who can open the manager (ownership)
FLRP_GZ.Command   = 'greenzones'       -- /greenzones (+ /gz alias)

-- Per-zone toggles offered in the manager. `key` matches a DB column opt_<key>.
FLRP_GZ.Options = {
  { key = 'weapons',  label = 'Disable Weapons',      desc = 'Holsters weapons and blocks firing/melee.' },
  { key = 'damage',   label = 'God Mode (No Damage)', desc = 'Players cannot take or deal damage.' },
  { key = 'vehicles', label = 'No Vehicles',          desc = 'Players cannot enter or drive vehicles here.' },
}
FLRP_GZ.DefaultRadius = 30.0
FLRP_GZ.MinRadius     = 5.0
FLRP_GZ.MaxRadius     = 300.0

-- Zones auto-created on first boot (matched by name, so they seed once — after
-- that, move/resize/delete them freely in /greenzones and it won't re-add them).
-- Radii are generous so each fully encompasses its station / hospital.
FLRP_GZ.DefaultZones = {
  { name = 'Mission Row PD',    x = 440.83,  y = -984.53, z = 22.85, radius = 75.0, weapons = true, damage = true, vehicles = false },
  { name = 'BSO Sandy Station', x = 1850.71, y = 3700.96, z = 33.76, radius = 60.0, weapons = true, damage = true, vehicles = false },
  { name = 'FHP HQ',            x = 2821.90, y = 4763.21, z = 47.37, radius = 60.0, weapons = true, damage = true, vehicles = false },
  { name = 'Sandy Hospital',    x = 1741.63, y = 3637.54, z = 44.86, radius = 55.0, weapons = true, damage = true, vehicles = false },
}

-- Map blip for each zone.
FLRP_GZ.Blip = { colour = 2, alpha = 80, sprite = 492 }  -- 2 = green

-- On-screen notices (via flrp_notify).
FLRP_GZ.EnterText = 'You are in a safezone. Do not do any violation here.'
FLRP_GZ.LeaveText = 'You have left the safezone.'

FLRP_GZ.Logo       = 'https://www.flrp.us/images/c8452f76261f8e9c.png'
FLRP_GZ.ServerName = 'Florida Roleplay'
