-- ==========================================================================
-- FLRP :: flrp_permissions/server/permissions.lua — per-player cache + checks
-- ==========================================================================
-- Holds each connected player's resolved roles + effective permissions and
-- answers HasPermission(). This is the AUTHORITATIVE check used by every other
-- FLRP resource. Never trust the client — always resolve server-side.
-- ==========================================================================

FLRPP = FLRPP or {}
FLRPP.Players = {}          -- source -> { playerId, license, roleList, roleKeys, permissions }

-- Discord role IDs discovered by flrp_access during the deferral, keyed by
-- license so we can resolve once flrp_core loads the player.
FLRPP.PendingDiscordRoles = {} -- license -> { roleIds... }

-- Apply a full resolution for a connected source.
function FLRPP.ApplyForSource(source)
  source = tonumber(source)
  local rec = exports.flrp_core:GetPlayer(source)
  if not rec then
    FLRP.Logger.Warn('permissions', 'ApplyForSource: no core record', { source = source })
    return false
  end

  local discordRoleIds = FLRPP.PendingDiscordRoles[rec.license] or {}
  local resolved = FLRPP.Resolver.Resolve(rec.playerId, discordRoleIds)

  FLRPP.Players[source] = {
    playerId = rec.playerId,
    license = rec.license,
    roleList = resolved.roleList,
    roleKeys = resolved.roleKeys,
    permissions = resolved.permissions,
  }

  -- Mirror to ACE for vMenu.
  FLRPP.Ace.Apply(rec.license, resolved.roleKeys)

  FLRP.Logger.Info('permissions', 'Resolved player permissions', {
    source = source, playerId = rec.playerId, roles = resolved.roleList,
  })
  TriggerEvent('flrp_permissions:applied', source, resolved.roleList)
  return true
end

function FLRPP.Remove(source)
  source = tonumber(source)
  local p = FLRPP.Players[source]
  if p and p.license then FLRPP.Ace.Remove(p.license) end
  FLRPP.Players[source] = nil
end

-- Authoritative permission check.
function FLRPP.HasPermission(source, permKey)
  source = tonumber(source)
  local p = FLRPP.Players[source]
  if not p then return false end
  local v = p.permissions[permKey]
  if v ~= nil then return v end
  -- Unknown permission key: fall back to its DB default if defined, else deny.
  local perm = FLRPP.Store.permsByKey[permKey]
  if perm then return perm.default_effect == 'allow' end
  return false
end

function FLRPP.HasAnyPermission(source, permKeys)
  for _, k in ipairs(permKeys or {}) do
    if FLRPP.HasPermission(source, k) then return true end
  end
  return false
end

function FLRPP.IsInGroup(source, roleKey)
  source = tonumber(source)
  local p = FLRPP.Players[source]
  return p ~= nil and p.roleKeys[roleKey] == true
end

function FLRPP.GetRoles(source)
  source = tonumber(source)
  local p = FLRPP.Players[source]
  return p and p.roleList or {}
end

function FLRPP.GetEffectivePermissions(source)
  source = tonumber(source)
  local p = FLRPP.Players[source]
  return p and p.permissions or {}
end

-- Re-apply for everyone currently connected (after a reload).
function FLRPP.ReapplyAll()
  for src in pairs(FLRPP.Players) do
    FLRPP.ApplyForSource(src)
  end
end
