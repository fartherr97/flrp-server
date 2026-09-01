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
  discordMap = {},        -- discordRoleId -> { roleKey, ... }
}

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

-- Merge convar-driven Discord role IDs (from secrets.cfg) into the mapping so
-- the server is usable before any discord_role_mappings rows exist. DB rows
-- take precedence / add to these.
local CONVAR_ROLE_MAP = {
  flrp_role_community_member = 'member',
  flrp_role_ownership        = 'ownership',
  flrp_role_director         = 'director',
  flrp_role_administrator    = 'administrator',
  flrp_role_moderator        = 'moderator',
  flrp_role_cert_civ_1       = 'cert_civ_1',
  flrp_role_cert_civ_2       = 'cert_civ_2',
  flrp_role_cert_civ_3       = 'cert_civ_3',
  flrp_role_bcso             = 'bcso',
  flrp_role_fhp              = 'fhp',
  flrp_role_mpd              = 'mpd',
}

local function addDiscordMap(discordRoleId, roleKey)
  if not discordRoleId or discordRoleId == '' or discordRoleId == 'REPLACE_ME' then return end
  local m = FLRPP.Store.discordMap
  m[discordRoleId] = m[discordRoleId] or {}
  for _, existing in ipairs(m[discordRoleId]) do
    if existing == roleKey then return end
  end
  m[discordRoleId][#m[discordRoleId] + 1] = roleKey
end

function FLRPP.Store.Load()
  local DB = FLRP.DB
  if not DB.IsReady() then return false end

  local store = FLRPP.Store
  store.rolesByKey, store.rolesById = {}, {}
  store.permsByKey, store.rolePerms = {}, {}
  store.discordMap = {}

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

  -- Discord mappings from DB.
  local dm = DB.Query([[
    SELECT drm.`discord_role_id` AS drid, r.`key` AS role_key
    FROM `discord_role_mappings` drm
    JOIN `roles` r ON r.id = drm.role_id
    WHERE drm.`enabled` = 1
  ]]) or {}
  for _, row in ipairs(dm) do
    addDiscordMap(row.drid, row.role_key)
  end

  -- Merge convar-driven mappings (bootstrap).
  for convar, roleKey in pairs(CONVAR_ROLE_MAP) do
    local id = GetConvar(convar, '')
    addDiscordMap(id, roleKey)
  end

  buildAncestors()
  store.loaded = true
  FLRP.Logger.Info('permissions', 'Permission store loaded', {
    roles = (function() local n=0 for _ in pairs(store.rolesByKey) do n=n+1 end return n end)(),
    permissions = (function() local n=0 for _ in pairs(store.permsByKey) do n=n+1 end return n end)(),
    discordMappings = (function() local n=0 for _ in pairs(store.discordMap) do n=n+1 end return n end)(),
  })
  return true
end
