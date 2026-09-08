-- ==========================================================================
-- FLRP :: flrp_postal/client.lua — /p <postal> GPS waypoint
-- ==========================================================================
-- Parses the postal dataset (sent by the server) into code -> {x,y} and, on
-- /p <postal>, drops a map waypoint so the minimap draws a GPS route there.
-- Open to everyone. /pc clears the waypoint.
-- ==========================================================================

local postals = {}     -- [codeString] = { x, y }
local ready   = false

local function notify(msg, bad)
  TriggerEvent('chat:addMessage', {
    color = bad and { 231, 76, 60 } or { 46, 204, 113 },
    args  = { 'Postal', msg },
  })
end

-- Accept common shapes: an array of { x, y, code|number|postal } objects, or a
-- { code = { x, y } } map. Codes are indexed as-is AND numerically-normalized
-- so "/p 083" and "/p 83" both resolve.
local function parse(raw)
  local out = {}
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= 'table' then return out end

  local function put(code, x, y)
    code = tostring(code):gsub('%s+', ''):upper()
    x, y = tonumber(x), tonumber(y)
    if code == '' or not x or not y then return end
    out[code] = { x = x + 0.0, y = y + 0.0 }
    local n = tonumber(code)                      -- also index "83" for "083"
    if n and not out[tostring(n)] then out[tostring(n)] = out[code] end
  end

  for k, v in pairs(data) do
    if type(v) == 'table' then
      local code = v.code or v.number or v.postal or v.name or (type(k) == 'string' and k) or nil
      put(code, v.x or v.X, v.y or v.Y)
    end
  end
  return out
end

RegisterNetEvent('flrp_postal:data', function(raw)
  if type(raw) == 'string' and raw ~= '' then
    postals = parse(raw)
    ready = next(postals) ~= nil
  end
end)

local function request() TriggerServerEvent('flrp_postal:request') end
AddEventHandler('onClientResourceStart', function(r) if r == GetCurrentResourceName() then request() end end)
CreateThread(function() while not NetworkIsSessionStarted() do Wait(500) end; Wait(500); request() end)

local function find(code)
  code = tostring(code):gsub('%s+', ''):upper()
  if postals[code] then return postals[code], code end
  local n = tonumber(code)
  if n and postals[tostring(n)] then return postals[tostring(n)], code end
  return nil
end

RegisterCommand('p', function(_, args)
  local code = args[1]
  if not code or code == '' then return notify('Usage: /p <postal>  (e.g. /p 140)', true) end
  if not ready then return notify('Postal data is still loading — try again in a moment.', true) end
  local p = find(code)
  if not p then return notify(('Postal "%s" not found.'):format(code), true) end
  SetNewWaypoint(p.x, p.y)
  notify(('GPS set to postal %s — follow the route on your minimap.'):format(tostring(code):upper()))
end, false)

RegisterCommand('pc', function()
  SetWaypointOff()
  notify('GPS waypoint cleared.')
end, false)

TriggerEvent('chat:addSuggestion', '/p', 'Set a GPS waypoint to a postal code', {
  { name = 'postal', help = 'Postal number shown on the map, e.g. 140' },
})
TriggerEvent('chat:addSuggestion', '/pc', 'Clear your GPS waypoint')
