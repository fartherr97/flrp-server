-- ==========================================================================
-- FLRP :: flrp_api/server/handlers.lua — endpoint implementations
-- ==========================================================================
-- The FLRP Manager contract. Read endpoints expose the current model; write
-- endpoints mutate the DB and are AUDITED. Values are validated server-side.
-- This is a representative, extensible set — add endpoints here as the Manager
-- grows. See docs/WEBSITE_INTEGRATION.md for the full contract.
-- ==========================================================================

FLRPI = FLRPI or {}

local function audit(ctx, category, action, targetType, targetId, oldV, newV)
  FLRP.Logger.Audit({
    actorIdentifier = 'flrp_manager', category = category, action = action,
    targetType = targetType, targetId = tostring(targetId),
    oldValue = oldV, newValue = newV, source = 'manager',
  })
end

-- ---- Health --------------------------------------------------------------
FLRPI.Router.Add('GET', '/health', function()
  return 200, { ok = true, ready = exports.flrp_core:IsReady() == true, service = 'flrp_api' }
end)

-- ---- Live config sync webhook (called by florida-roleplay-site on save) ---
-- POST body: { scope: 'all'|'permissions'|'mappings'|'vehicles'|'weapons'|'payrates' }
-- Pulls the authoritative config for that scope from the site read API and
-- re-applies to all ONLINE players immediately — no restart. See
-- docs/LIVE_CONFIG_SYNC.md.
FLRPI.Router.Add('POST', '/sync', function(ctx)
  local scope = (ctx.body and ctx.body.scope) or 'all'
  local ok, res = FLRPI.Sync.PullAndApply(scope)
  if not ok then return 502, { error = res or 'sync_failed' } end
  return 200, { ok = true, scope = scope, applied = res }
end)

-- Manual trigger (no site pull) to re-apply the current cache live — useful for
-- ops / testing without the site. Returns online players re-applied.
FLRPI.Router.Add('POST', '/sync/reapply', function()
  return 200, { ok = true, applied = FLRPI.Sync.ReapplyLive() }
end)

-- ---- Permissions: matrix (Owner/Director/Admin/CivIII/BCSO/FHP/MPD ...) ---
FLRPI.Router.Add('GET', '/permissions/matrix', function()
  if not exports.flrp_permissions then return 503, { error = 'permissions_unavailable' } end
  return 200, exports.flrp_permissions:GetPermissionMatrix()
end)

-- ---- Permissions: set a role's effect for a permission (audited) ---------
-- POST body: { roleKey, permissionKey, effect: 'allow'|'deny'|'inherit' }
--   'inherit' removes the explicit row (falls back to default/inheritance).
FLRPI.Router.Add('POST', '/permissions/role_permission', function(ctx)
  local b = ctx.body or {}
  if type(b.roleKey) ~= 'string' or type(b.permissionKey) ~= 'string' then
    return 400, { error = 'bad_input' }
  end
  local effect = b.effect or 'allow'
  local role = FLRP.DB.Single('SELECT id FROM `roles` WHERE `key` = ?', { b.roleKey })
  local perm = FLRP.DB.Single('SELECT id FROM `permissions` WHERE `key` = ?', { b.permissionKey })
  if not role or not perm then return 404, { error = 'unknown_role_or_permission' } end

  if effect == 'inherit' then
    FLRP.DB.Update('DELETE FROM `role_permissions` WHERE `role_id` = ? AND `permission_id` = ?',
      { role.id, perm.id })
  elseif effect == 'allow' or effect == 'deny' then
    FLRP.DB.Update([[
      INSERT INTO `role_permissions` (`role_id`, `permission_id`, `effect`)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE `effect` = VALUES(`effect`)
    ]], { role.id, perm.id, effect })
  else
    return 400, { error = 'bad_effect' }
  end

  audit(ctx, 'permissions', 'set_role_permission', 'role_permission',
    b.roleKey .. ':' .. b.permissionKey, nil, { effect = effect })
  if exports.flrp_permissions then exports.flrp_permissions:ReloadPermissions() end
  return 200, { ok = true }
end)

-- ---- Roles / Departments -------------------------------------------------
FLRPI.Router.Add('GET', '/roles', function()
  return 200, { roles = FLRP.DB.Query('SELECT `key`,`name`,`kind`,`priority`,`is_department` FROM `roles`') or {} }
end)

-- ---- Discord role mappings (add) ----------------------------------------
-- POST body: { discordRoleId, roleKey, note? }
FLRPI.Router.Add('POST', '/discord_mappings', function(ctx)
  local b = ctx.body or {}
  if type(b.discordRoleId) ~= 'string' or type(b.roleKey) ~= 'string' then
    return 400, { error = 'bad_input' }
  end
  local role = FLRP.DB.Single('SELECT id FROM `roles` WHERE `key` = ?', { b.roleKey })
  if not role then return 404, { error = 'unknown_role' } end
  FLRP.DB.Update([[
    INSERT INTO `discord_role_mappings` (`discord_role_id`, `role_id`, `note`)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE `note` = VALUES(`note`), `enabled` = 1
  ]], { b.discordRoleId, role.id, b.note })
  audit(ctx, 'roles', 'map_discord_role', 'role', b.roleKey, nil, { discordRoleId = b.discordRoleId })
  if exports.flrp_permissions then exports.flrp_permissions:ReloadPermissions() end
  return 200, { ok = true }
end)

-- ---- Economy: pay rates (read) ------------------------------------------
FLRPI.Router.Add('GET', '/economy/payrates', function()
  local rows = FLRP.DB.Query([[
    SELECT r.`key` AS role_key, pr.`hourly_cents`, pr.`enabled`
    FROM `pay_rates` pr JOIN `roles` r ON r.id = pr.role_id
  ]]) or {}
  return 200, { payRates = rows }
end)

-- ---- Economy: set a pay rate (audited) ----------------------------------
-- POST body: { roleKey, hourlyCents, enabled? }
FLRPI.Router.Add('POST', '/economy/payrates', function(ctx)
  local b = ctx.body or {}
  if type(b.roleKey) ~= 'string' or type(b.hourlyCents) ~= 'number' then
    return 400, { error = 'bad_input' }
  end
  if b.hourlyCents < 0 or b.hourlyCents > 100000000 then return 400, { error = 'out_of_range' } end
  local role = FLRP.DB.Single('SELECT id FROM `roles` WHERE `key` = ?', { b.roleKey })
  if not role then return 404, { error = 'unknown_role' } end
  local old = FLRP.DB.Single('SELECT `hourly_cents` FROM `pay_rates` WHERE `role_id` = ?', { role.id })
  FLRP.DB.Update([[
    INSERT INTO `pay_rates` (`role_id`, `hourly_cents`, `enabled`)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE `hourly_cents` = VALUES(`hourly_cents`), `enabled` = VALUES(`enabled`)
  ]], { role.id, math.floor(b.hourlyCents), (b.enabled == false) and 0 or 1 })
  audit(ctx, 'economy', 'set_pay_rate', 'role', b.roleKey,
    old and { hourlyCents = old.hourly_cents } or nil, { hourlyCents = math.floor(b.hourlyCents) })
  return 200, { ok = true }
end)

-- ---- Config (read/write) ------------------------------------------------
FLRPI.Router.Add('GET', '/config', function()
  return 200, { config = FLRP.DB.Query('SELECT `key`,`value`,`value_type`,`category` FROM `configuration`') or {} }
end)
FLRPI.Router.Add('POST', '/config', function(ctx)
  local b = ctx.body or {}
  if type(b.key) ~= 'string' then return 400, { error = 'bad_input' } end
  exports.flrp_core:SetConfig(b.key, b.value, b.valueType or 'string', 'flrp_manager')
  audit(ctx, 'economy', 'set_config', 'config', b.key, nil, { value = b.value })
  return 200, { ok = true }
end)

-- ---- Weapons (read/upsert) ----------------------------------------------
FLRPI.Router.Add('GET', '/weapons', function()
  return 200, { weapons = FLRP.DB.Query('SELECT * FROM `weapons`') or {} }
end)
FLRPI.Router.Add('POST', '/weapons', function(ctx)
  local b = ctx.body or {}
  if type(b.weaponName) ~= 'string' or type(b.displayName) ~= 'string' then
    return 400, { error = 'bad_input' }
  end
  FLRP.DB.Update([[
    INSERT INTO `weapons`
      (`weapon_name`,`display_name`,`enabled`,`gunstore_available`,`price_cents`,
       `cert_required`,`required_permission`,`vmenu_spawnable`,`notes`)
    VALUES (?,?,?,?,?,?,?,?,?)
    ON DUPLICATE KEY UPDATE `display_name`=VALUES(`display_name`),
      `enabled`=VALUES(`enabled`), `gunstore_available`=VALUES(`gunstore_available`),
      `price_cents`=VALUES(`price_cents`), `cert_required`=VALUES(`cert_required`),
      `required_permission`=VALUES(`required_permission`),
      `vmenu_spawnable`=VALUES(`vmenu_spawnable`), `notes`=VALUES(`notes`)
  ]], {
    string.upper(b.weaponName), b.displayName, (b.enabled == false) and 0 or 1,
    b.gunstoreAvailable and 1 or 0, math.floor(tonumber(b.priceCents) or 0),
    b.certRequired, b.requiredPermission, b.vmenuSpawnable and 1 or 0, b.notes })
  audit(ctx, 'weapons', 'upsert_weapon', 'weapon', string.upper(b.weaponName), nil, b)
  if exports.flrp_weapons then exports.flrp_weapons:ReloadRegistry() end
  return 200, { ok = true }
end)

-- ---- Vehicles (read/upsert) ---------------------------------------------
FLRPI.Router.Add('GET', '/vehicles', function()
  return 200, { vehicles = FLRP.DB.Query('SELECT * FROM `vehicles`') or {} }
end)
FLRPI.Router.Add('POST', '/vehicles', function(ctx)
  local b = ctx.body or {}
  if not exports.flrp_vehicles then return 503, { error = 'vehicles_unavailable' } end
  local ok, err = exports.flrp_vehicles:RegisterVehicle(b)
  if not ok then return 400, { error = err or 'bad_input' } end
  audit(ctx, 'vehicles', 'upsert_vehicle', 'vehicle', b.spawnName, nil, b)
  exports.flrp_vehicles:ReloadRegistry()
  return 200, { ok = true }
end)

-- ---- Audit log (read; append-only, never writable via API) --------------
FLRPI.Router.Add('GET', '/audit', function(ctx)
  local limit = 50
  local rows = FLRP.DB.Query([[
    SELECT `id`,`actor_identifier`,`actor_discord_id`,`category`,`action`,
           `target_type`,`target_id`,`reason`,`source`,`created_at`
    FROM `audit_logs` ORDER BY `id` DESC LIMIT ?
  ]], { limit }) or {}
  return 200, { audit = rows }
end)
