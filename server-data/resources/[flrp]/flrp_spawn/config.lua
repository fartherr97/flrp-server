-- ==========================================================================
-- FLRP :: flrp_spawn/config.lua — spawn selector points
-- ==========================================================================
-- Each point: name, coords vector4(x, y, z, heading), and an optional `ace`.
-- When `ace` is set, only players whose principal holds that ace may spawn
-- there (checked SERVER-SIDE in server.lua). `flrp.leo` = any sworn BSO/FHP/MPD
-- member (see config/permissions.cfg). Use flrp.dept.bso/fhp/mpd for one dept.
-- ==========================================================================
Config = Config or {}

Config.Points = {
  { name = 'Legion Square',      area = 'Los Santos',    coords = vector4(197.94, -932.4, 30.69, 320.0) },
  { name = 'Pillbox Hill',       area = 'Los Santos',    coords = vector4(298.98, -584.45, 43.26, 70.0) },
  { name = 'LS Airport',         area = 'Los Santos',    coords = vector4(-1037.74, -2738.04, 20.17, 330.0) },
  { name = 'Mission Row PD',     area = 'MPD — LEO only', coords = vector4(428.23, -984.28, 30.71, 0.0), ace = 'flrp.leo' },
  { name = 'Sandy Shores',       area = 'Blaine County', coords = vector4(1884.41, 3714.45, 32.93, 210.0) },
  { name = 'Paleto Bay',         area = 'Blaine County', coords = vector4(-134.20, 6212.20, 31.21, 47.09) },
  { name = 'Grapeseed',          area = 'Blaine County', coords = vector4(1654.72, 4825.46, 42.08, 280.0) },
  { name = 'Vinewood',           area = 'Los Santos',    coords = vector4(436.64, 218.38, 103.62, 160.0) },
  { name = 'Del Perro',          area = 'Los Santos',    coords = vector4(-1341.27, -1298.66, 4.84, 292.0) },
  { name = 'Mirror Park',        area = 'Los Santos',    coords = vector4(1130.21, -645.9, 56.58, 272.0) },
}

-- Camera position while the selector is open (high over the map).
Config.Camera = {
  pos  = vector3(-410.0, -5021.0, 3000.0),
  rot  = vector3(-40.0, 0.0, 0.0),
  fov  = 45.0,
}

Config.LogoUrl = 'https://www.flrp.us/images/c8452f76261f8e9c.png'
