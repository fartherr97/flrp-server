-- ==========================================================================
-- FLRP :: flrp_vehicles/server/registry.lua — vehicle registry + checks
-- ==========================================================================
-- In-memory cache of the `vehicles` table + `vehicle_permissions`. The DB is
-- the source of truth (editable by the FLRP Manager and populated at asset
-- import). Spawn permission is resolved server-side against flrp_permissions.
-- ==========================================================================

FLRPV = FLRPV or {}
FLRPV.Registry = { bySpawn = {}, loaded = false }

local function norm(name)
  if type(name) ~= 'string' then return nil end
  return string.lower(name)
end
FLRPV.Registry.Normalize = norm

function FLRPV.Registry.Load()
  if not FLRP.DB.IsReady() then return false end
  local vehicles = FLRP.DB.Query('SELECT * FROM `vehicles`') or {}
  local extraPerms = FLRP.DB.Query('SELECT `vehicle_id`, `permission_key` FROM `vehicle_permissions`') or {}

  local permsByVehicle = {}
  for _, row in ipairs(extraPerms) do
    permsByVehicle[row.vehicle_id] = permsByVehicle[row.vehicle_id] or {}
    permsByVehicle[row.vehicle_id][#permsByVehicle[row.vehicle_id] + 1] = row.permission_key
  end

  local map = {}
  for _, v in ipairs(vehicles) do
    map[norm(v.spawn_name)] = {
      id = v.id,
      spawnName = norm(v.spawn_name),
      displayName = v.display_name,
      resource = v.resource,
      department = v.department,
      category = v.category,
      minRank = v.min_rank,
      certification = v.certification,          -- roles.key or nil
      requiredPermission = v.required_permission, -- permissions.key or nil
      enabled = v.enabled == 1,
      notes = v.notes,
      extraPermissions = permsByVehicle[v.id] or {},
    }
  end
  FLRPV.Registry.bySpawn = map
  FLRPV.Registry.loaded = true
  FLRP.Logger.Info('vehicles', 'Vehicle registry loaded', {
    count = (function() local n=0 for _ in pairs(map) do n=n+1 end return n end)() })
  return true
end

function FLRPV.Registry.Get(spawnName)
  return FLRPV.Registry.bySpawn[norm(spawnName)]
end

-- Authoritative spawn-permission check.
-- Returns ok(bool), reason. Behaviour for UNLISTED vehicles is governed by the
-- `flrp_vehicles_allow_unlisted` convar (default true -> defer to vMenu's own
-- ACE checks; false -> only registry-listed permitted vehicles may spawn).
function FLRPV.Registry.CanSpawn(source, spawnName)
  local enforce = FLRP.Util.ConvarBool('flrp_vehicles_enforce_permissions', true)
  if not enforce then return true, 'enforcement_disabled' end

  local v = FLRPV.Registry.Get(spawnName)
  if not v then
    local allowUnlisted = FLRP.Util.ConvarBool('flrp_vehicles_allow_unlisted', true)
    return allowUnlisted, allowUnlisted and 'unlisted_allowed' or 'unlisted_denied'
  end

  if not v.enabled then return false, 'disabled' end

  -- Certification gate (if set).
  if v.certification and v.certification ~= '' then
    if not (exports.flrp_permissions and exports.flrp_permissions:IsInGroup(source, v.certification)) then
      return false, 'need_certification'
    end
  end

  -- Permission gate: primary required_permission OR any extra permission.
  local perms = {}
  if v.requiredPermission and v.requiredPermission ~= '' then perms[#perms + 1] = v.requiredPermission end
  for _, p in ipairs(v.extraPermissions) do perms[#perms + 1] = p end

  if #perms == 0 then
    -- No permission requirement recorded -> allowed (enabled civilian vehicle).
    return true, 'no_permission_required'
  end

  if exports.flrp_permissions and exports.flrp_permissions:HasAnyPermission(source, perms) then
    return true, 'permitted'
  end
  return false, 'no_permission'
end

-- List registry vehicles this player may spawn (for a future spawn menu / UI).
function FLRPV.Registry.ListForPlayer(source)
  local out = {}
  for _, v in pairs(FLRPV.Registry.bySpawn) do
    if v.enabled then
      local ok = FLRPV.Registry.CanSpawn(source, v.spawnName)
      if ok then
        out[#out + 1] = {
          spawnName = v.spawnName, displayName = v.displayName,
          department = v.department, category = v.category,
        }
      end
    end
  end
  table.sort(out, function(a, b) return (a.displayName or '') < (b.displayName or '') end)
  return out
end

-- Upsert a vehicle into the registry (used by asset-import tooling / Manager).
function FLRPV.Registry.Register(v)
  if type(v) ~= 'table' or not v.spawnName or not v.displayName then return false, 'bad_input' end
  FLRP.DB.Update([[
    INSERT INTO `vehicles`
      (`spawn_name`,`display_name`,`resource`,`department`,`category`,`min_rank`,
       `certification`,`required_permission`,`enabled`,`notes`)
    VALUES (?,?,?,?,?,?,?,?,?,?)
    ON DUPLICATE KEY UPDATE `display_name`=VALUES(`display_name`),
      `resource`=VALUES(`resource`), `department`=VALUES(`department`),
      `category`=VALUES(`category`), `min_rank`=VALUES(`min_rank`),
      `certification`=VALUES(`certification`), `required_permission`=VALUES(`required_permission`),
      `enabled`=VALUES(`enabled`), `notes`=VALUES(`notes`)
  ]], {
    norm(v.spawnName), v.displayName, v.resource, v.department, v.category, v.minRank,
    v.certification, v.requiredPermission, (v.enabled == false) and 0 or 1, v.notes })
  return true
end
