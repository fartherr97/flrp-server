-- ==========================================================================
-- FLRP :: flrp_permissions/server/main.lua — boot + wiring
-- ==========================================================================

CreateThread(function()
  -- Wait for flrp_core DB readiness before loading the permission model.
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRPP.Store.Load()
  FLRP.Logger.Info('permissions', 'flrp_permissions ready')
  TriggerEvent('flrp_permissions:ready')
end)

-- Role membership comes from pCore via the ACE bridge (server/pcore.lua). By
-- the time flrp_core loads a player (playerJoining), pCore has already resolved
-- them during the connection deferral and attached their group principals, so
-- IsPlayerAceAllowed reflects their roles. We resolve + apply here.
AddEventHandler('flrp_core:playerLoaded', function(source, playerId, record)
  if not FLRPP.Store.loaded then FLRPP.Store.Load() end
  FLRPP.ApplyForSource(source)
end)

AddEventHandler('flrp_core:playerDropped', function(source, playerId)
  FLRPP.Remove(source)
end)

-- A Discord role change (pCore re-resolves + re-attaches group principals) takes
-- effect for FLRP on the player's next join, or immediately for everyone via the
-- console/admin `flrp_reload_perms` (which re-reads pCore ACE for all players).
-- We deliberately do NOT listen for the client-facing pDiscord:setPerms event —
-- it is client-triggerable and role membership must be read server-side only.

-- Console/admin reload command.
RegisterCommand('flrp_reload_perms', function(source)
  if source ~= 0 then
    -- In-game requires permissions.manage.
    if not FLRPP.HasPermission(source, 'permissions.manage') then
      FLRP.Logger.Warn('permissions', 'reload denied', { source = source })
      return
    end
  end
  local ok = FLRPP.Store.Load()
  if ok then FLRPP.ReapplyAll() end
  FLRP.Logger.Info('permissions', 'ReloadPermissions (command)', { ok = ok })
end, false)
