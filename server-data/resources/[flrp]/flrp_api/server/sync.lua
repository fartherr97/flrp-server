-- ==========================================================================
-- FLRP :: flrp_api/server/sync.lua — live config sync from the website
-- ==========================================================================
-- The website (florida-roleplay-site, Postgres) is the source of truth. This
-- module keeps the FLRP MySQL cache in sync and RE-APPLIES to online players
-- immediately — no server restart, no pCore rebuild. See docs/LIVE_CONFIG_SYNC.md.
--
-- Two triggers:
--   * Push: the site calls flrp_api `POST /sync { scope }` on save.
--   * Pull reconcile: a background thread pulls `scope=all` every N minutes to
--     self-heal any missed webhook.
--
-- Site read API (defined by our contract):
--   GET  <flrp_site_api_url>/api/fivem/config?scope=<scope>
--   header  X-FLRP-Secret: <flrp_site_api_secret>
--   ->  { roles[], permissions[], role_permissions[], pay_rates[],
--         weapons[], vehicles[] }   (only the requested scope's keys required)
-- ==========================================================================

FLRPI = FLRPI or {}
FLRPI.Sync = {}

local function cfg(name, default) return GetConvar(name, default or '') end

local function siteConfigured()
  local url = cfg('flrp_site_api_url')
  local sec = cfg('flrp_site_api_secret')
  return url ~= '' and url ~= 'REPLACE_ME' and sec ~= '' and sec ~= 'REPLACE_ME'
end

-- Blocking HTTP GET of the site config for a scope. Returns table or nil, err.
function FLRPI.Sync.Pull(scope)
  if not siteConfigured() then return nil, 'site_not_configured' end
  scope = scope or 'all'
  local base = cfg('flrp_site_api_url'):gsub('/+$', '')
  local url = ('%s/api/fivem/config?scope=%s'):format(base, scope)

  local p = promise.new()
  PerformHttpRequest(url, function(status, body, _headers)
    p:resolve({ status = status, body = body })
  end, 'GET', '', {
    ['X-FLRP-Secret'] = cfg('flrp_site_api_secret'),
    ['Accept'] = 'application/json',
    ['User-Agent'] = 'FLRP-Sync (flrp_api)',
  })
  local res = Citizen.Await(p)
  if res.status ~= 200 then
    FLRP.Logger.Warn('sync', 'Site config pull failed', { scope = scope, status = res.status })
    return nil, ('http_%s'):format(tostring(res.status))
  end
  local ok, decoded = pcall(json.decode, res.body)
  if not ok or type(decoded) ~= 'table' then return nil, 'bad_json' end
  return decoded
end

-- ---- Cache writers (idempotent upserts into the FLRP MySQL cache) ---------

local function applyRoles(rows)
  for _, r in ipairs(rows or {}) do
    FLRP.DB.Update([[
      INSERT INTO `roles` (`key`,`name`,`kind`,`priority`,`is_department`)
      VALUES (?,?,?,?,?)
      ON DUPLICATE KEY UPDATE `name`=VALUES(`name`), `kind`=VALUES(`kind`),
        `priority`=VALUES(`priority`), `is_department`=VALUES(`is_department`)
    ]], { r.key, r.name or r.key, r.kind or 'base', tonumber(r.priority) or 0,
          r.is_department and 1 or 0 })
  end
  -- Resolve inheritance (parent by key) in a second pass.
  for _, r in ipairs(rows or {}) do
    if r.inherits and r.inherits ~= '' then
      FLRP.DB.Update([[
        UPDATE `roles` SET `inherits_role_id` =
          (SELECT id FROM (SELECT id,`key` FROM `roles`) t WHERE t.`key` = ?)
        WHERE `key` = ?
      ]], { r.inherits, r.key })
    end
  end
end

local function applyPermissions(rows)
  for _, p in ipairs(rows or {}) do
    FLRP.DB.Update([[
      INSERT INTO `permissions` (`key`,`description`,`category`,`default_effect`)
      VALUES (?,?,?,?)
      ON DUPLICATE KEY UPDATE `description`=VALUES(`description`),
        `category`=VALUES(`category`), `default_effect`=VALUES(`default_effect`)
    ]], { p.key, p.description, p.category or 'general',
          (p.default_effect == 'allow') and 'allow' or 'deny' })
  end
end

-- role_permissions is a full replace so REMOVED grants propagate live.
local function applyRolePermissions(rows)
  if rows == nil then return end -- scope didn't include it; leave cache as-is
  FLRP.DB.Update('DELETE FROM `role_permissions`')
  for _, rp in ipairs(rows) do
    FLRP.DB.Update([[
      INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`,`effect`)
      SELECT r.id, p.id, ? FROM `roles` r JOIN `permissions` p
      WHERE r.`key` = ? AND p.`key` = ?
    ]], { (rp.effect == 'deny') and 'deny' or 'allow', rp.role_key, rp.permission_key })
  end
end

local function applyPayRates(rows)
  for _, pr in ipairs(rows or {}) do
    FLRP.DB.Update([[
      INSERT INTO `pay_rates` (`role_id`,`hourly_cents`,`enabled`)
      SELECT id, ?, ? FROM `roles` WHERE `key` = ?
      ON DUPLICATE KEY UPDATE `hourly_cents`=VALUES(`hourly_cents`), `enabled`=VALUES(`enabled`)
    ]], { math.floor(tonumber(pr.hourly_cents) or 0), (pr.enabled == false) and 0 or 1, pr.role_key })
  end
end

local function applyWeapons(rows)
  for _, w in ipairs(rows or {}) do
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
    ]], { string.upper(w.weapon_name), w.display_name or w.weapon_name,
          (w.enabled == false) and 0 or 1, w.gunstore_available and 1 or 0,
          math.floor(tonumber(w.price_cents) or 0), w.cert_required,
          w.required_permission, w.vmenu_spawnable and 1 or 0, w.notes })
  end
end

local function applyVehicles(rows)
  for _, v in ipairs(rows or {}) do
    if exports.flrp_vehicles then
      exports.flrp_vehicles:RegisterVehicle({
        spawnName = v.spawn_name, displayName = v.display_name or v.spawn_name,
        resource = v.resource, department = v.department, category = v.category,
        minRank = v.min_rank, certification = v.certification,
        requiredPermission = v.required_permission, enabled = v.enabled ~= false,
        notes = v.notes,
      })
    end
  end
end

-- Apply a pulled config into the cache, then RE-APPLY live to online players.
-- Returns applied-player count.
function FLRPI.Sync.Apply(config)
  if type(config) ~= 'table' or not FLRP.DB.IsReady() then return 0 end

  applyRoles(config.roles)
  applyPermissions(config.permissions)
  applyRolePermissions(config.role_permissions)
  applyPayRates(config.pay_rates)
  applyWeapons(config.weapons)
  applyVehicles(config.vehicles)

  return FLRPI.Sync.ReapplyLive()
end

-- Reload every FLRP cache from the DB and re-apply to all ONLINE players NOW.
-- This is the "no restart" step. Returns online player count re-applied.
function FLRPI.Sync.ReapplyLive()
  -- permissions: reload store + re-resolve every connected source (this also
  -- re-reads pCore ACE membership, so any role change is picked up live).
  if exports.flrp_permissions then pcall(function() exports.flrp_permissions:ReloadPermissions() end) end
  -- economy pay rates.
  if exports.flrp_economy then pcall(function() exports.flrp_economy:ReloadPayRates() end) end
  -- registries.
  if exports.flrp_weapons then pcall(function() exports.flrp_weapons:ReloadRegistry() end) end
  if exports.flrp_vehicles then pcall(function() exports.flrp_vehicles:ReloadRegistry() end) end

  local n = 0
  for _ in pairs(GetPlayers()) do n = n + 1 end
  FLRP.Logger.Info('sync', 'Config re-applied live', { onlinePlayers = n })
  TriggerEvent('flrp_sync:applied')
  return n
end

-- Pull a scope from the site and apply it. Returns ok, appliedOrErr.
function FLRPI.Sync.PullAndApply(scope)
  local config, err = FLRPI.Sync.Pull(scope or 'all')
  if not config then return false, err end
  return true, FLRPI.Sync.Apply(config)
end

-- Background reconcile loop (self-heals missed webhooks).
function FLRPI.Sync.StartReconcile()
  if not siteConfigured() then
    FLRP.Logger.Info('sync', 'Site not configured; live sync idle (set flrp_site_api_url/secret)')
    return
  end
  local mins = math.max(1, math.floor(tonumber(cfg('flrp_sync_interval_minutes', '10')) or 10))
  CreateThread(function()
    while true do
      Wait(mins * 60000)
      local ok, res = FLRPI.Sync.PullAndApply('all')
      FLRP.Logger.Debug('sync', 'Reconcile pull', { ok = ok, result = res })
    end
  end)
  FLRP.Logger.Info('sync', 'Live config sync enabled', { reconcileMinutes = mins })
end
