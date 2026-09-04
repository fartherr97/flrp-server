-- ==========================================================================
-- FLRP :: flrp_greenzone/server.lua — safe zone store + sync (authoritative)
-- ==========================================================================

local ready  = false
local zones  = {}   -- id -> row

local function isOwner(src) return IsPlayerAceAllowed(src, FLRP_GZ.ManageAce) end
local function name(src) return GetPlayerName(src) or ('Player ' .. src) end
local function licenseOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'license:' then return id end
  end
  return nil
end

local function clampRadius(r)
  r = tonumber(r) or FLRP_GZ.DefaultRadius
  return math.max(FLRP_GZ.MinRadius, math.min(FLRP_GZ.MaxRadius, r))
end

-- ---- db ------------------------------------------------------------------
CreateThread(function()
  while not FLRP.DB.IsReady() do Wait(500) end
  FLRP.DB.Update([[CREATE TABLE IF NOT EXISTS `greenzones` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(64) NOT NULL,
    `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
    `radius` DOUBLE NOT NULL DEFAULT 30,
    `opt_weapons` TINYINT NOT NULL DEFAULT 1,
    `opt_damage` TINYINT NOT NULL DEFAULT 1,
    `opt_vehicles` TINYINT NOT NULL DEFAULT 0,
    `created_by` VARCHAR(64) )]])
  local rows = FLRP.DB.Query('SELECT * FROM `greenzones`') or {}
  zones = {}
  for _, r in ipairs(rows) do zones[r.id] = r end
  ready = true
  print(('[flrp_greenzone] ready — %d zone(s).'):format(#rows))
end)

-- The list every client keeps + enforces.
local function publicList()
  local out = {}
  for _, r in pairs(zones) do
    out[#out + 1] = {
      id = r.id, name = r.name, x = r.x, y = r.y, z = r.z, radius = r.radius,
      weapons = r.opt_weapons == 1, damage = r.opt_damage == 1, vehicles = r.opt_vehicles == 1,
    }
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

local function broadcast()
  TriggerClientEvent('flrp_greenzone:zones', -1, publicList())
end

-- A joining client asks for the current zones.
RegisterNetEvent('flrp_greenzone:request', function()
  if ready then TriggerClientEvent('flrp_greenzone:zones', source, publicList()) end
end)

-- ---- manager (req/res) ---------------------------------------------------
local function stateFor(src)
  return { ok = true, owner = isOwner(src), zones = publicList(), options = FLRP_GZ.Options,
           minRadius = FLRP_GZ.MinRadius, maxRadius = FLRP_GZ.MaxRadius, defaultRadius = FLRP_GZ.DefaultRadius,
           logo = GetConvar('flrp_reports_logo', FLRP_GZ.Logo), serverName = FLRP_GZ.ServerName }
end

local H = {}
function H.state(src) return stateFor(src) end

function H.create(src, p)
  if not isOwner(src) then return { ok = false, error = 'Ownership only.' } end
  local nm = tostring(p.name or 'Safe Zone'):sub(1, 64)
  local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
  if not (x and y and z) then return { ok = false, error = 'Missing location.' } end
  local rad = clampRadius(p.radius)
  local id = FLRP.DB.Insert(
    'INSERT INTO `greenzones` (`name`,`x`,`y`,`z`,`radius`,`opt_weapons`,`opt_damage`,`opt_vehicles`,`created_by`) VALUES (?,?,?,?,?,?,?,?,?)',
    { nm, x, y, z, rad, p.weapons ~= false and 1 or 0, p.damage ~= false and 1 or 0, p.vehicles == true and 1 or 0, licenseOf(src) })
  if not id then return { ok = false, error = 'Database error.' } end
  zones[id] = { id = id, name = nm, x = x, y = y, z = z, radius = rad,
                opt_weapons = p.weapons ~= false and 1 or 0, opt_damage = p.damage ~= false and 1 or 0,
                opt_vehicles = p.vehicles == true and 1 or 0 }
  broadcast()
  return stateFor(src)
end

function H.update(src, p)
  if not isOwner(src) then return { ok = false, error = 'Ownership only.' } end
  local r = zones[tonumber(p.id or 0)]; if not r then return { ok = false, error = 'Zone not found.' } end
  if p.name ~= nil then r.name = tostring(p.name):sub(1, 64) end
  if p.radius ~= nil then r.radius = clampRadius(p.radius) end
  if p.weapons ~= nil then r.opt_weapons = p.weapons and 1 or 0 end
  if p.damage ~= nil then r.opt_damage = p.damage and 1 or 0 end
  if p.vehicles ~= nil then r.opt_vehicles = p.vehicles and 1 or 0 end
  FLRP.DB.Update('UPDATE `greenzones` SET `name`=?,`radius`=?,`opt_weapons`=?,`opt_damage`=?,`opt_vehicles`=? WHERE `id`=?',
    { r.name, r.radius, r.opt_weapons, r.opt_damage, r.opt_vehicles, r.id })
  broadcast()
  return stateFor(src)
end

function H.delete(src, p)
  if not isOwner(src) then return { ok = false, error = 'Ownership only.' } end
  local id = tonumber(p.id or 0)
  if not zones[id] then return { ok = false, error = 'Zone not found.' } end
  zones[id] = nil
  FLRP.DB.Update('DELETE FROM `greenzones` WHERE `id`=?', { id })
  broadcast()
  return stateFor(src)
end

RegisterNetEvent('flrp_greenzone:req', function(action, payload, reqId)
  local src = source
  if type(src) ~= 'number' or src <= 0 then return end
  payload = type(payload) == 'table' and payload or {}
  local res
  if not ready then
    res = { ok = false, error = 'Green zones starting — try again in a moment.' }
  else
    local h = H[tostring(action)]
    if not h or (action ~= 'state' and not isOwner(src)) then
      res = { ok = false, error = 'Ownership only.' }
    else
      local ok, r = pcall(h, src, payload)
      if ok and type(r) == 'table' then res = r
      else print(('[flrp_greenzone] handler %s failed: %s'):format(tostring(action), tostring(r))); res = { ok = false, error = 'Server error.' } end
    end
  end
  TriggerClientEvent('flrp_greenzone:res', src, reqId, res)
end)
