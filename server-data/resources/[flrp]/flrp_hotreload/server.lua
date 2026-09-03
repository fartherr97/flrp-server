-- ==========================================================================
-- FLRP :: flrp_hotreload/server.lua — live deploy applier (no full restart)
-- ==========================================================================
-- autodeploy.sh writes a small queue file after a `git reset --hard`, listing
-- exactly what changed:
--     refresh
--     resource flrp_reports
--     resource flrp_status
--     cfg permissions.cfg
-- This resource polls that file and applies each line LIVE — `refresh` to make
-- new resources discoverable, stop+start to reload a resource's code, and
-- `exec config/<file>` to re-apply a cfg — none of which disconnect players.
-- Only genuinely structural changes (server.cfg, OneSync, deps, content/maps)
-- still trigger a full `systemctl restart` in autodeploy.
--
-- SECURITY: the queue is a LOCAL file written only by the VPS deploy process
-- (never network-exposed). Even so, every token is validated against a strict
-- allowlist below, and only three verbs are honoured — a malformed or unknown
-- line is ignored, never executed.
-- ==========================================================================

local QUEUE    = GetConvar('flrp_hotreload_queue', '/opt/fivem/flrp-server/deploy/.hotreload.queue')
local INTERVAL = 3000

-- strict token validators (no slashes, no "..", no shell/command injection)
local function validResource(s) return type(s) == 'string' and s:match('^[%w_%-]+$') ~= nil end
local function validCfg(s)      return type(s) == 'string' and s:match('^[%w_%-%.]+%.cfg$') ~= nil and not s:find('%.%.') end

local function readAndClear()
  local f = io.open(QUEUE, 'r')
  if not f then return nil end
  local data = f:read('*a')
  f:close()
  os.remove(QUEUE)                       -- consume it (idempotent)
  if not data or data:gsub('%s', '') == '' then return nil end
  return data
end

local function apply(data)
  local doRefresh = false
  local order, seen = {}, {}
  for raw in data:gmatch('[^\r\n]+') do
    local line = raw:gsub('^%s+', ''):gsub('%s+$', '')
    if line ~= '' and line:sub(1, 1) ~= '#' then
      local verb, arg = line:match('^(%S+)%s*(%S*)$')
      if verb == 'refresh' then
        doRefresh = true
      elseif verb == 'resource' and validResource(arg) and arg ~= GetCurrentResourceName() then
        local key = 'r:' .. arg
        if not seen[key] then seen[key] = true; order[#order + 1] = { 'resource', arg } end
      elseif verb == 'cfg' and validCfg(arg) then
        local key = 'c:' .. arg
        if not seen[key] then seen[key] = true; order[#order + 1] = { 'cfg', arg } end
      else
        print(('[flrp_hotreload] ignored line: %q'):format(line))
      end
    end
  end

  if doRefresh or #order > 0 then
    ExecuteCommand('refresh')            -- discover new/changed manifests
    Wait(600)
  end
  for _, item in ipairs(order) do
    if item[1] == 'resource' then
      print(('[flrp_hotreload] reloading resource %s'):format(item[2]))
      ExecuteCommand('stop ' .. item[2])
      Wait(300)
      ExecuteCommand('start ' .. item[2])
    else
      print(('[flrp_hotreload] exec config/%s'):format(item[2]))
      ExecuteCommand('exec config/' .. item[2])
    end
    Wait(150)
  end
  print(('[flrp_hotreload] applied %d reload(s) live — no restart'):format(#order))
end

CreateThread(function()
  Wait(2000)
  print('[flrp_hotreload] watching ' .. QUEUE)
  while true do
    Wait(INTERVAL)
    local ok, data = pcall(readAndClear)
    if ok and data then
      local ok2, err = pcall(apply, data)
      if not ok2 then print('[flrp_hotreload] apply error: ' .. tostring(err)) end
    end
  end
end)
