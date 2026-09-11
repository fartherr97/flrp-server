-- ==========================================================================
-- FLRP :: flrp_permissions/server/main.lua — boot + wiring
-- ==========================================================================

CreateThread(function()
  -- Wait for flrp_core DB readiness before loading the permission model.
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRPP.Store.Load()

  -- Re-apply the static ACE grants from permissions.cfg. cfg files are ONLY
  -- exec'd at a full server start, so a resource-only restart (e.g. after a
  -- content autodeploy) would leave the server running with STALE ace grants —
  -- which is exactly what silently breaks /setaop, /sc, /editor and the vMenu
  -- weapon policy after a deploy. Re-execing here makes the grants self-heal
  -- whenever flrp_permissions (re)starts. Re-exec is idempotent.
  Wait(2000)
  ExecuteCommand('exec config/permissions.cfg')
  FLRP.Logger.Info('permissions', 'Re-exec config/permissions.cfg (ACE grants refreshed)')

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

-- Console diagnostic: flrp_perms <serverId>
-- Prints everything the permission pipeline knows about ONE connected player
-- (Discord role IDs the gate saw, which convar role mappings matched, the
-- resolved FLRP roles, the ACE groups attached, and live IsPlayerAceAllowed
-- results for the vMenu time/weather aces). Console-only, or permissions.manage.
RegisterCommand('flrp_perms', function(source, args)
  if source ~= 0 and not FLRPP.HasPermission(source, 'permissions.manage') then return end
  local target = tonumber(args[1] or '')
  if not target or GetPlayerName(target) == nil then
    print('[flrp_perms] usage: flrp_perms <serverId>  (player must be connected)')
    return
  end
  local rec = exports.flrp_core:GetPlayer(target)
  local license = (rec and rec.license) or FLRP.Identity.GetLicense(target)
  local roleIds = license and FLRPP.PendingDiscordRoles[license] or nil
  local out = {}
  local function line(fmt, ...) out[#out + 1] = fmt:format(...) end

  line('== flrp_perms: [%s] %s ==', tostring(target), tostring(GetPlayerName(target)))
  line('license: %s   core record: %s', tostring(license), rec and 'yes' or 'NO')
  line('discord role ids seen at connect: %s', roleIds
    and (#roleIds > 0 and (#roleIds .. ' -> ' .. table.concat(roleIds, ', ')) or '0')
    or 'NONE (gate never published)')

  -- Which configured convar roles does this player actually hold?
  local held, missing = {}, {}
  local seen = {}
  for _, id in ipairs(roleIds or {}) do seen[tostring(id)] = true end
  for convar, key in pairs(FLRPP.Store.ConvarRoleMap or {}) do
    local id = GetConvar(convar, '')
    if id ~= '' and id ~= 'REPLACE_ME' then
      if seen[id] then held[#held + 1] = key .. '=' .. id else missing[#missing + 1] = key end
    end
  end
  table.sort(held); table.sort(missing)
  line('mapped roles HELD: %s', #held > 0 and table.concat(held, ', ') or '(none)')
  line('mapped roles not held: %s', table.concat(missing, ', '))

  local p = FLRPP.Players[target]
  line('resolved flrp roles: %s', p and table.concat(p.roleList or {}, ', ') or '(not resolved yet)')
  local groups = {}
  for g in pairs((license and FLRPP.Ace.applied[license]) or {}) do groups[#groups + 1] = g end
  table.sort(groups)
  line('ACE groups attached: %s', #groups > 0 and table.concat(groups, ', ') or '(none)')

  -- ace -> a reference group we expect to grant it, printed alongside the
  -- player's live result so you can see BOTH that the player is (or isn't)
  -- allowed AND that the grant chain in permissions.cfg is intact.
  local aces = {
    { 'flrp.leo',                  'group.flrp.leo_access' },
    { 'flrp.dept.bso',             'group.flrp.bso' },
    { 'flrp.dept.fhp',             'group.flrp.fhp' },
    { 'flrp.dept.mpd',             'group.flrp.mpd' },
    { 'vMenu.Everything',          'group.flrp.media' },
    { 'vMenu.TimeOptions.Menu',    'group.flrp.media' },
    { 'vMenu.TimeOptions.All',     'group.flrp.media' },
    { 'vMenu.WeatherOptions.Menu', 'group.flrp.media' },
    { 'vMenu.WeatherOptions.All',  'group.flrp.media' },
  }
  for _, a in ipairs(aces) do
    line('  IsPlayerAceAllowed %-28s player=%s  %s=%s', a[1],
      tostring(IsPlayerAceAllowed(target, a[1])), a[2], tostring(IsPrincipalAceAllowed(a[2], a[1])))
  end
  print(table.concat(out, '\n'))
end, true)

-- Console/admin reload command.
RegisterCommand('flrp_reload_perms', function(source)
  if source ~= 0 then
    -- In-game requires permissions.manage.
    if not FLRPP.HasPermission(source, 'permissions.manage') then
      FLRP.Logger.Warn('permissions', 'reload denied', { source = source })
      return
    end
  end
  ExecuteCommand('exec config/permissions.cfg')  -- refresh static ACE grants too
  local ok = FLRPP.Store.Load()
  if ok then FLRPP.ReapplyAll() end
  FLRP.Logger.Info('permissions', 'ReloadPermissions (command)', { ok = ok })
end, false)
