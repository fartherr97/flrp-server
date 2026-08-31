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

function ReloadPermissions()
  local ok = FLRPP.Store.Load()
  if ok then FLRPP.ReapplyAll() end
  FLRP.Logger.Info('permissions', 'ReloadPermissions', { ok = ok })
  return ok
end

-- Build the role×permission matrix for the FLRP Manager UI. Resolves each
-- role's effective permission (including inheritance + deny-beats-allow) so
-- the website can render Owner/Director/Admin/CivIII/BCSO/FHP/MPD exactly.
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
