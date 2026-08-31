-- ==========================================================================
-- FLRP :: flrp_permissions/server/resolver.lua — effective permission resolver
-- ==========================================================================
-- Turns a player's raw inputs (Discord role IDs + explicit player_roles) into:
--   * an expanded set of role keys (inheritance applied)
--   * an effective permission map: { permKey = true/false }
--
-- Resolution rules (documented in docs/PERMISSIONS.md):
--   1. Base role 'member' is always present for a verified player.
--   2. Discord role IDs are mapped to role keys via the store.
--   3. Explicit player_roles rows are added.
--   4. Each role is expanded to include inherited ancestors.
--   5. For a permission: any explicit 'deny' wins; else any 'allow' grants;
--      else the permission's default_effect; else deny.
-- ==========================================================================

FLRPP = FLRPP or {}
FLRPP.Resolver = {}

-- Given discord role IDs (array of strings) -> set of FLRP role keys.
local function rolesFromDiscord(discordRoleIds)
  local set = {}
  local map = FLRPP.Store.discordMap
  for _, drid in ipairs(discordRoleIds or {}) do
    local mapped = map[tostring(drid)]
    if mapped then
      for _, rk in ipairs(mapped) do set[rk] = true end
    end
  end
  return set
end

-- Load explicit, non-expired player_roles for a players.id.
local function rolesFromPlayerRoles(playerId)
  local set = {}
  if not playerId or not FLRP.DB.IsReady() then return set end
  local rows = FLRP.DB.Query([[
    SELECT r.`key` AS role_key
    FROM `player_roles` pr
    JOIN `roles` r ON r.id = pr.role_id
    WHERE pr.player_id = ?
      AND (pr.expires_at IS NULL OR pr.expires_at > CURRENT_TIMESTAMP)
  ]], { playerId })
  for _, row in ipairs(rows or {}) do set[row.role_key] = true end
  return set
end

-- Expand a role-key set to include inherited ancestors.
local function expandInheritance(roleSet)
  local expanded = {}
  for key in pairs(roleSet) do
    local chain = FLRPP.Store.ancestors[key]
    if chain then
      for _, k in ipairs(chain) do expanded[k] = true end
    else
      expanded[key] = true
    end
  end
  return expanded
end

-- Compute effective permission booleans from an expanded role-key set.
local function computePermissions(expandedRoles)
  local store = FLRPP.Store
  -- Gather explicit effects across all roles.
  local sawAllow, sawDeny = {}, {}
  for key in pairs(expandedRoles) do
    local role = store.rolesByKey[key]
    if role then
      local perms = store.rolePerms[role.id] or {}
      for permKey, effect in pairs(perms) do
        if effect == 'deny' then sawDeny[permKey] = true
        elseif effect == 'allow' then sawAllow[permKey] = true end
      end
    end
  end

  local effective = {}
  -- Consider every known permission so defaults are represented.
  for permKey, perm in pairs(store.permsByKey) do
    if sawDeny[permKey] then
      effective[permKey] = false
    elseif sawAllow[permKey] then
      effective[permKey] = true
    else
      effective[permKey] = (perm.default_effect == 'allow')
    end
  end
  return effective
end

-- Full resolve. Returns { roleKeys = {set}, roleList = {array},
--                          permissions = { permKey = bool } }.
function FLRPP.Resolver.Resolve(playerId, discordRoleIds)
  local base = { member = true }
  local fromDiscord = rolesFromDiscord(discordRoleIds)
  local fromPlayer = rolesFromPlayerRoles(playerId)

  local roleSet = {}
  for k in pairs(base) do roleSet[k] = true end
  for k in pairs(fromDiscord) do roleSet[k] = true end
  for k in pairs(fromPlayer) do roleSet[k] = true end

  local expanded = expandInheritance(roleSet)

  local roleList = {}
  for k in pairs(expanded) do roleList[#roleList + 1] = k end
  table.sort(roleList)

  return {
    roleKeys = expanded,
    roleList = roleList,
    permissions = computePermissions(expanded),
  }
end
