-- ==========================================================================
-- FLRP :: flrp_core/server/util.lua — small helpers
-- ==========================================================================
FLRP = FLRP or {}
FLRP.Util = {}

-- Safe integer coercion (returns fallback on nil/garbage).
function FLRP.Util.ToInt(v, fallback)
  local n = tonumber(v)
  if n == nil then return fallback end
  return math.floor(n)
end

-- Truthy convar read ('true'/'1'/'yes' => true).
function FLRP.Util.ConvarBool(name, default)
  local v = GetConvar(name, default and 'true' or 'false')
  v = string.lower(v)
  return v == 'true' or v == '1' or v == 'yes'
end

-- Trim helper.
function FLRP.Util.Trim(s)
  if type(s) ~= 'string' then return s end
  return (s:gsub('^%s*(.-)%s*$', '%1'))
end

-- Shallow copy.
function FLRP.Util.Copy(t)
  if type(t) ~= 'table' then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

-- Returns true if `source` looks like a valid connected player id.
function FLRP.Util.IsValidSource(source)
  source = tonumber(source)
  if not source or source <= 0 then return false end
  -- GetPlayerName returns nil for a disconnected/invalid source.
  return GetPlayerName(source) ~= nil
end

-- Generate a reasonably-unique idempotency key for a given action + source.
-- Not cryptographic; used to defeat accidental double-submits within a window.
function FLRP.Util.IdempotencyKey(prefix, source, salt)
  return string.format('%s:%s:%s:%d', prefix, tostring(source),
    tostring(salt or ''), math.floor(GetGameTimer()))
end
