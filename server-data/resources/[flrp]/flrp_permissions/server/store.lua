-- ==========================================================================
-- FLRP :: flrp_permissions/server/store.lua — role/permission data store
-- ==========================================================================
-- Loads and indexes the permission model from the DB. Rebuilt on boot and on
-- ReloadPermissions(). Everything here is READ-ONLY snapshot state; per-player
-- resolution happens in resolver.lua.
-- ==========================================================================

FLRPP = FLRPP or {}
FLRPP.Store = {
  loaded = false,
  rolesByKey = {},        -- key   -> role row
  rolesById  = {},        -- id    -> role row
  permsByKey = {},        -- key   -> permission row (has default_effect)
  rolePerms  = {},        -- roleId-> { permKey = 'allow'|'deny' }
  ancestors  = {},        -- roleKey -> { roleKey, ...(self + inherited) }
}
-- NOTE: Discord role -> FLRP role mapping is NOT done here anymore. pCore owns
-- Discord; FLRP reads role membership via the ACE bridge (server/pcore.lua).
-- The DB `discord_role_mappings` table is left in place for the website/Manager
-- but is not consumed by this resource.

local function buildAncestors()
  local store = FLRPP.Store
  store.ancestors = {}
  for key, role in pairs(store.rolesByKey) do
    local chain, seen = {}, {}
    local cur = role
    local guard = 0
    while cur and not seen[cur.key] and guard < 32 do
      seen[cur.key] = true
      chain[#chain + 1] = cur.key
      guard = guard + 1
      cur = cur.inherits_role_id and store.rolesById[cur.inherits_role_id] or nil
    end
    store.ancestors[key] = chain
  end
end

function FLRPP.Store.Load()
  local DB = FLRP.DB
  if not DB.IsReady() then return false end

  local store = FLRPP.Store
  store.rolesByKey, store.rolesById = {}, {}
  store.permsByKey, store.rolePerms = {}, {}

  for _, r in ipairs(DB.Query('SELECT * FROM `roles`') or {}) do
    store.rolesByKey[r.key] = r
    store.rolesById[r.id] = r
    store.rolePerms[r.id] = store.rolePerms[r.id] or {}
  end

  for _, p in ipairs(DB.Query('SELECT * FROM `permissions`') or {}) do
    store.permsByKey[p.key] = p
  end

  local rows = DB.Query([[
    SELECT rp.`role_id` AS role_id, p.`key` AS perm_key, rp.`effect` AS effect
    FROM `role_permissions` rp
    JOIN `permissions` p ON p.id = rp.permission_id
  ]]) or {}
  for _, row in ipairs(rows) do
    store.rolePerms[row.role_id] = store.rolePerms[row.role_id] or {}
    store.rolePerms[row.role_id][row.perm_key] = row.effect
  end

  buildAncestors()
  store.loaded = true
  FLRP.Logger.Info('permissions', 'Permission store loaded', {
    roles = (function() local n=0 for _ in pairs(store.rolesByKey) do n=n+1 end return n end)(),
    permissions = (function() local n=0 for _ in pairs(store.permsByKey) do n=n+1 end return n end)(),
  })
  return true
end
