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

-- flrp_access publishes the Discord roles it read during the connection gate.
-- Payload: (license, discordRoleIds[]). We stash by license and resolve when
-- flrp_core loads the player. This is a SERVER-side event only (never a
-- RegisterNetEvent), so a client cannot inject its own roles. This keeps
-- flrp_access -> flrp_permissions a one-way, event-based dependency (no cycle).
AddEventHandler('flrp_access:discordRolesResolved', function(license, discordRoleIds)
  if type(license) ~= 'string' then return end
  FLRPP.PendingDiscordRoles[license] = discordRoleIds or {}
  -- Attach the ACE group principals NOW, during the connection gate, so vMenu
  -- (and any other ACE consumer) sees the player's groups BEFORE the client
  -- requests permissions on spawn. Waiting until flrp_core:playerLoaded races
  -- vMenu's permission read and leaves the player with only builtin.everyone
  -- perms (locked weapons / empty menu). The full player record + DB-role
  -- resolution still runs on playerLoaded via ApplyForSource (idempotent —
  -- Ace.Apply removes then re-adds).
  if not FLRPP.Store.loaded then FLRPP.Store.Load() end
  local ok, resolved = pcall(FLRPP.Resolver.Resolve, nil, discordRoleIds)
  if ok and resolved and resolved.roleKeys then
    FLRPP.Ace.Apply(license, resolved.roleKeys)
  end
  FLRP.Logger.Debug('permissions', 'Pending roles stored + ACE pre-attached', {
    license = license, count = #(discordRoleIds or {}) })
end)

-- When flrp_core finishes loading a player, resolve + apply their permissions.
AddEventHandler('flrp_core:playerLoaded', function(source, playerId, record)
  -- Ensure the store is loaded.
  if not FLRPP.Store.loaded then FLRPP.Store.Load() end
  FLRPP.ApplyForSource(source)
end)

AddEventHandler('flrp_core:playerDropped', function(source, playerId)
  FLRPP.Remove(source)
  -- Keep pending discord roles only briefly; clear on drop by license lookup.
end)

AddEventHandler('playerDropped', function()
  local rec = exports.flrp_core:GetPlayer(source)
  if rec and rec.license then FLRPP.PendingDiscordRoles[rec.license] = nil end
end)

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
