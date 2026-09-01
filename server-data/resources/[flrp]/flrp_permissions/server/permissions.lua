-- ==========================================================================
-- FLRP :: flrp_permissions/server/permissions.lua — per-player cache + checks
-- ==========================================================================
-- Holds each connected player's resolved roles + effective permissions and
-- answers HasPermission(). This is the AUTHORITATIVE check used by every other
-- FLRP resource. Never trust the client — always resolve server-side.
-- ==========================================================================

FLRPP = FLRPP or {}
FLRPP.Players = {}          -- source -> { playerId, license, roleList, roleKeys, permissions }

-- Apply a full resolution for a connected source. Role membership comes from
-- pCore via the ACE bridge (server/pcore.lua); the DB matrix decides effect.
function FLRPP.ApplyForSource(source)
  source = tonumber(source)
  local rec = exports.flrp_core:GetPlayer(source)
  if not rec then
    FLRP.Logger.Warn('permissions', 'ApplyForSource: no core record', { source = source })
    return false
  end

  local roleKeys = FLRPP.PCore.GetFlrpRoleKeys(source)
  local resolved = FLRPP.Resolver.Resolve(rec.playerId, roleKeys)

  FLRPP.Players[source] = {
    playerId = rec.playerId,
    license = rec.license,
    roleList = resolved.roleList,
    roleKeys = resolved.roleKeys,
    permissions = resolved.permissions,
  }

  -- NOTE: vMenu ACE is owned by pCore; FLRP does not attach principals here.

  FLRP.Logger.Info('permissions', 'Resolved player permissions', {
    source = source, playerId = rec.playerId, roles = resolved.roleList,
  })
  TriggerEvent('flrp_permissions:applied', source, resolved.roleList)
  return true
end

function FLRPP.Remove(source)
  source = tonumber(source)
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
