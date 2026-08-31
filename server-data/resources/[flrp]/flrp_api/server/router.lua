-- ==========================================================================
-- FLRP :: flrp_api/server/router.lua — tiny router + auth
-- ==========================================================================
-- Minimal method+path router with shared-secret authentication and JSON
-- helpers. The shared secret comes from the private convar
-- `flrp_api_shared_secret` (config/secrets.cfg) and is compared in constant
-- time. Requests without a valid secret get 401. See docs/SECURITY.md.
-- ==========================================================================

FLRPI = FLRPI or {}
FLRPI.Router = { routes = {} }

-- Register a handler: method ('GET'/'POST'), path pattern (exact), fn(ctx)->(status, tableBody)
function FLRPI.Router.Add(method, path, fn)
  FLRPI.Router.routes[method .. ' ' .. path] = fn
end

-- Constant-time string compare (avoids trivial timing oracle on the secret).
local function ctEquals(a, b)
  if type(a) ~= 'string' or type(b) ~= 'string' then return false end
  if #a ~= #b then return false end
  local diff = 0
  for i = 1, #a do
    diff = diff | (string.byte(a, i) ~ string.byte(b, i))
  end
  return diff == 0
end

local function getSecret()
  return GetConvar('flrp_api_shared_secret', '')
end

function FLRPI.Router.Authorized(headers)
  local secret = getSecret()
  if secret == '' or secret == 'REPLACE_ME' then
    -- Not configured: refuse everything (fail closed).
    return false, 'api_not_configured'
  end
  -- Accept header 'X-FLRP-Secret' (case-insensitive lookup).
  local provided
  for k, v in pairs(headers or {}) do
    if string.lower(k) == 'x-flrp-secret' then provided = v break end
  end
  if not provided then return false, 'missing_secret' end
  if not ctEquals(provided, secret) then return false, 'bad_secret' end
  return true
end

function FLRPI.Router.Dispatch(method, path, headers, bodyStr)
  local key = method .. ' ' .. path
  local fn = FLRPI.Router.routes[key]
  if not fn then return 404, { error = 'not_found' } end

  local ok, reason = FLRPI.Router.Authorized(headers)
  if not ok then
    return (reason == 'api_not_configured') and 503 or 401, { error = reason }
  end

  local body = nil
  if bodyStr and bodyStr ~= '' then
    local decoded
    local pok = pcall(function() decoded = json.decode(bodyStr) end)
    if pok then body = decoded end
  end

  local sok, status, respBody = pcall(fn, { headers = headers, body = body })
  if not sok then
    FLRP.Logger.Error('api', 'Handler error', { key = key, err = tostring(status) })
    return 500, { error = 'internal_error' }
  end
  return status or 200, respBody or {}
end
