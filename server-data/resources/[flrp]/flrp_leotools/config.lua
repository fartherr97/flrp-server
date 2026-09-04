-- ==========================================================================
-- FLRP :: flrp_leotools/config.lua — LEO restraint tools (cuff / drag / seat)
-- ==========================================================================
-- Server-authoritative cuff, escort (drag) and put-in-vehicle actions for
-- sworn law enforcement (flrp.leo). Driven from the flrp_interact LEO Toolbox
-- and by /cuff, /drag, /seat commands. No external deps.
-- ==========================================================================

FLRP_LEO = {}

FLRP_LEO.Ace       = 'flrp.leo'   -- who may use these tools
FLRP_LEO.Reach     = 3.0          -- metres: how close the officer must be to a target
FLRP_LEO.SeatReach = 6.0          -- metres: how close a vehicle must be to seat someone

-- Cuffed animation + movement.
FLRP_LEO.Cuff = {
  animDict = 'mp_arresting',
  anim     = 'idle',
  clipset  = 'move_m@prisoner_cuffed',   -- lets a cuffed ped walk, hands behind back
}

-- Drag attach offset (target attached in front of the officer).
FLRP_LEO.Drag = {
  bone = 11816,        -- SKEL spine bone
  x = 0.30, y = 0.45, z = 0.0,
  rx = 0.0, ry = 0.0, rz = 0.0,
}

-- Spike strips (native stinger prop; each driver bursts their own tyres over it).
FLRP_LEO.Spike = {
  model       = 'p_ld_stinger_s',
  ahead       = 2.5,    -- metres in front of the officer to lay it
  burstRadius = 3.2,    -- metres from a spike that bursts tyres
  minSpeed    = 4.0,    -- m/s minimum speed to pop (stops parked cars deflating)
  reach       = 8.0,    -- metres to find the nearest spike to remove
}
