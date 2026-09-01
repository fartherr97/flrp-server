-- ==========================================================================
-- FLRP :: flrp_duty/server/main.lua — boot + cache lifecycle
-- ==========================================================================

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRP.Logger.Info('duty', 'flrp_duty ready (nex-duty adapter)', {
    entityMap = FLRPD.BuildEntityMap() })
end)

AddEventHandler('flrp_core:playerDropped', function(source)
  FLRPD.Remove(source)
end)

-- Rebuild the entity->department map (after changing convars) + clear cache.
RegisterCommand('flrp_reload_duty', function(source)
  if source ~= 0 and not (exports.flrp_permissions and exports.flrp_permissions:HasPermission(source, 'permissions.manage')) then
    return
  end
  FLRPD.entityMap = nil
  FLRPD.Invalidate()
  FLRP.Logger.Info('duty', 'Duty adapter reloaded (entity map + cache cleared)')
end, false)
