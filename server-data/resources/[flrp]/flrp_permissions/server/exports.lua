-- ==========================================================================
-- FLRP :: flrp_permissions/server/exports.lua — public API
-- ==========================================================================
--   exports.flrp_permissions:HasPermission(source, key)      -> bool
--   exports.flrp_permissions:HasAnyPermission(source, {keys}) -> bool
--   exports.flrp_permissions:GetRoles(source)                -> { roleKey... }
--   exports.flrp_permissions:IsInGroup(source, roleKey)      -> bool
--   exports.flrp_permissions:GetEffectivePermissions(source) -> { key=bool }
--   exports.flrp_permissions:ReloadPermissions()             -> bool
--   exports.flrp_permissions:ApplyForSource(source)          -> bool
--   exports.flrp_permissions:GetPermissionMatrix()           -> matrix (for FLRP Manager)
-- ==========================================================================

function HasPermission(source, key) return FLRPP.HasPermission(source, key) end
function HasAnyPermission(source, keys) return FLRPP.HasAnyPermission(source, keys) end
function GetRoles(source) return FLRPP.GetRoles(source) end
function IsInGroup(source, roleKey) return FLRPP.IsInGroup(source, roleKey) end
function GetEffectivePermissions(source) return FLRPP.GetEffectivePermissions(source) end
function ApplyForSource(source) return FLRPP.ApplyForSource(source) end

-- Resolve a list of raw Discord role IDs to a set of FLRP role keys, using the
-- same discordMap the gate uses. Pure lookup (no source needed) — used by the
-- connection gate to decide name-enforcement group/exemption before a player
-- has a real server id. Returns { roleKey = true, ... }.
function ResolveDiscordRoles(roleIds)
  local out = {}
  local map = (FLRPP.Store and FLRPP.Store.discordMap) or {}
  for _, id in ipairs(roleIds or {}) do
    local keys = map[tostring(id)]
    if keys then for _, k in ipairs(keys) do out[k] = true end end
  end
  return out
end

-- Like ResolveDiscordRoles but returns each resolved role's KIND
-- ('base' | 'staff' | 'certification' | 'department') as { [roleKey] = kind }.
-- Lets callers act on categories instead of an exhaustive key list, so new
-- cert tiers / staff ranks are covered automatically once they're mapped.
function ResolveDiscordRoleKinds(roleIds)
  local out = {}
  local map   = (FLRPP.Store and FLRPP.Store.discordMap) or {}
  local roles = (FLRPP.Store and FLRPP.Store.rolesByKey) or {}
  for _, id in ipairs(roleIds or {}) do
    local keys = map[tostring(id)]
    if keys then
      for _, k in ipairs(keys) do
        out[k] = (roles[k] and roles[k].kind) or 'unknown'
      end
    end
  end
  return out
end

function ReloadPermissions()
  local ok = FLRPP.Store.Load()
  if ok then FLRPP.ReapplyAll() end
  FLRP.Logger.Info('permissions', 'ReloadPermissions', { ok = ok })
  return ok
end

-- Build the role×permission matrix for the FLRP Manager UI. Resolves each
-- role's effective permission (including inheritance + deny-beats-allow) so
-- the website can render Owner/Director/Admin/CivIII/BSO/FHP/MPD exactly.
-- Returns { roles = {rowMeta}, permissions = {permMeta}, matrix = { [roleKey][permKey] = bool } }.
function GetPermissionMatrix()
  local store = FLRPP.Store
  local roles, permissions, matrix = {}, {}, {}

  for key, role in pairs(store.rolesByKey) do
    roles[#roles + 1] = { key = key, name = role.name, kind = role.kind,
      priority = role.priority, is_department = role.is_department == 1 }
  end
  for key, perm in pairs(store.permsByKey) do
    permissions[#permissions + 1] = { key = key, category = perm.category,
      description = perm.description, default_effect = perm.default_effect }
  end

  for roleKey in pairs(store.rolesByKey) do
    matrix[roleKey] = {}
    -- Expand inheritance for this single role.
    local expanded = {}
    local chain = store.ancestors[roleKey] or { roleKey }
    for _, k in ipairs(chain) do expanded[k] = true end
    -- deny-beats-allow across expanded roles.
    local sawAllow, sawDeny = {}, {}
    for k in pairs(expanded) do
      local r = store.rolesByKey[k]
      if r then
        for pk, eff in pairs(store.rolePerms[r.id] or {}) do
          if eff == 'deny' then sawDeny[pk] = true elseif eff == 'allow' then sawAllow[pk] = true end
        end
      end
    end
    for pk, perm in pairs(store.permsByKey) do
      local val
      if sawDeny[pk] then val = false
      elseif sawAllow[pk] then val = true
      else val = (perm.default_effect == 'allow') end
      matrix[roleKey][pk] = val
    end
  end

  return { roles = roles, permissions = permissions, matrix = matrix }
end
