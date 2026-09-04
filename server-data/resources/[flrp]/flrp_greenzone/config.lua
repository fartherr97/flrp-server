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

-- Map blip for each zone.
FLRP_GZ.Blip = { colour = 2, alpha = 80, sprite = 492 }  -- 2 = green

-- On-screen notices (via flrp_notify).
FLRP_GZ.EnterText = 'You are in a safezone. Do not do any violation here.'
FLRP_GZ.LeaveText = 'You have left the safezone.'

FLRP_GZ.Logo       = 'https://www.flrp.us/images/c8452f76261f8e9c.png'
FLRP_GZ.ServerName = 'Florida Roleplay'
