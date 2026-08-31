-- ==========================================================================
-- FLRP :: flrp_core/server/main.lua — boot + lifecycle
-- ==========================================================================
-- Brings flrp_core online: waits for oxmysql, probes the schema, loads config,
-- then wires player lifecycle. flrp_access performs the CONNECTION GATE during
-- the deferral; flrp_core loads the persistent record only AFTER a player has
-- been allowed in and has fully connected (playerJoining / first activity).
-- ==========================================================================

local function probeDatabase()
  -- Retry until oxmysql + schema are reachable.
  local attempts = 0
  while true do
    attempts = attempts + 1
    local ok, result = pcall(function()
      return FLRP.DB.Scalar('SELECT COUNT(*) FROM `schema_migrations`')
    end)
    if ok and result ~= nil then
      FLRP.DB._setReady(true)
      FLRP.Logger.Info('boot', 'Database reachable', { migrations = result })
      return true
    end
    if attempts <= 3 or attempts % 5 == 0 then
      FLRP.Logger.Warn('boot', 'Waiting for database/schema...', { attempt = attempts })
    end
    Wait(2000)
  end
end

CreateThread(function()
  FLRP.Logger.Info('boot', 'flrp_core starting')
  probeDatabase()

  if not FLRP.ConfigStore.Load() then
    FLRP.Logger.Warn('boot', 'Configuration load deferred (DB not ready?)')
  else
    FLRP.Logger.Info('boot', 'Configuration loaded',
      { keys = (function() local n=0 for _ in pairs(FLRP.ConfigStore.cache) do n=n+1 end return n end)() })
  end

  FLRP.Logger.Info('boot', 'flrp_core ready')
  TriggerEvent('flrp_core:ready')
end)

-- --------------------------------------------------------------------------
-- Player lifecycle
-- --------------------------------------------------------------------------
-- We load the persistent record when the player is fully joining. flrp_access
-- has already validated Discord membership during the deferral by this point.
AddEventHandler('playerJoining', function()
  local source = source
  -- Defer a tick so all identifiers are attached.
  CreateThread(function()
    Wait(250)
    FLRP.Player.Load(source)
  end)
end)

AddEventHandler('playerDropped', function()
  FLRP.Player.Drop(source)
end)

-- Admin/console command to hot-reload configuration from DB.
RegisterCommand('flrp_reload_config', function(source, args, raw)
  -- Console only (source 0) or players with permissions.manage (checked by
  -- flrp_permissions if present). Keep simple here: console-only.
  if source ~= 0 then
    FLRP.Logger.Warn('config', 'flrp_reload_config denied (console only)', { source = source })
    return
  end
  FLRP.ConfigStore.Load()
  FLRP.Logger.Info('config', 'Configuration reloaded from DB')
end, true)

-- Re-load any players already connected when the resource (re)starts.
AddEventHandler('onResourceStart', function(resName)
  if resName ~= GetCurrentResourceName() then return end
  CreateThread(function()
    Wait(3000) -- let DB probe finish
    for _, pid in ipairs(GetPlayers()) do
      FLRP.Player.Load(tonumber(pid))
    end
  end)
end)
