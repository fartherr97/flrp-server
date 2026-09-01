-- ==========================================================================
-- FLRP :: flrp_api/server/main.lua — HTTP endpoint binding
-- ==========================================================================
-- Binds the router to FiveM's HTTP handler. The FLRP Manager reaches this at
-- http(s)://<server-host>:<port>/<resource>/... which FiveM routes to this
-- resource. NOTE: exposing this publicly should be done behind the Manager's
-- own network boundary / reverse proxy; the shared secret is the auth. See
-- docs/WEBSITE_INTEGRATION.md and docs/SECURITY.md.
-- ==========================================================================

local function sendJson(res, status, body)
  local ok, encoded = pcall(json.encode, body)
  res.writeHead(status, {
    ['Content-Type'] = 'application/json; charset=utf-8',
    ['Cache-Control'] = 'no-store',
  })
  res.send(ok and encoded or '{"error":"encode_failed"}')
end

SetHttpHandler(function(req, res)
  local method = req.method
  -- req.path includes a leading '/'; strip any query string.
  local path = req.path or '/'
  local q = path:find('?', 1, true)
  if q then path = path:sub(1, q - 1) end

  local function handle(bodyStr)
    local status, body = FLRPI.Router.Dispatch(method, path, req.headers, bodyStr)
    sendJson(res, status, body)
  end

  if method == 'POST' or method == 'PUT' then
    req.setDataHandler(function(bodyStr) handle(bodyStr) end)
  else
    handle(nil)
  end
end)

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  local configured = GetConvar('flrp_api_shared_secret', '')
  configured = configured ~= '' and configured ~= 'REPLACE_ME'
  FLRP.Logger.Info('api', 'flrp_api ready', { configured = configured })
  if not configured then
    FLRP.Logger.Warn('api', 'flrp_api_shared_secret not set — API refuses all requests until configured')
  end

  -- Start the live config-sync reconcile loop (website is source of truth).
  FLRPI.Sync.StartReconcile()
end)
