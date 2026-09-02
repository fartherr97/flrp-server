-- ==========================================================================
-- FLRP :: flrp_status/server.lua — live server-status embed
-- ==========================================================================
-- Posts one embed to the status webhook, then edits that same message every
-- UpdateSeconds so it stays a single live message. AOP/priority come from
-- nex-hud exports; on-duty counts from nex-duty; players/staff/vehicles from
-- server natives.
-- ==========================================================================

local WEBHOOK, JOIN_URL = '', ''
local msgId = nil
local debugged = false

local function refreshConvars()
  WEBHOOK  = GetConvar(FLRP_STATUS.WebhookConvar, '')
  JOIN_URL = GetConvar(FLRP_STATUS.JoinUrlConvar, '')
end

-- "https://discord.com/api/webhooks/{id}/{token}" (query stripped), or nil.
local function webhookBase()
  if WEBHOOK == '' or not WEBHOOK:find('discord') then return nil end
  return (WEBHOOK:gsub('%?.*$', ''))
end

local function safeCall(fn)
  local ok, res = pcall(fn)
  if ok then return res end
  return nil
end

-- ---- data sources --------------------------------------------------------
local function maxPlayers() return GetConvarInt('sv_maxclients', 64) end

local function countUnits(entities)
  if not entities or #entities == 0 then return 0 end
  local u = safeCall(function() return exports['nex-duty']:getUnitsByEntities(entities) end)
  return (type(u) == 'table') and #u or 0
end

local function staffOnline()
  local lines, count = {}, 0
  for _, pid in ipairs(GetPlayers()) do
    pid = tonumber(pid)
    if pid and IsPlayerAceAllowed(pid, FLRP_STATUS.StaffAce) then
      count = count + 1
      lines[#lines + 1] = GetPlayerName(pid) or ('Player ' .. pid)
    end
  end
  table.sort(lines)
  return count, lines
end

local function vehicleCount()
  local ok, v = pcall(GetAllVehicles)
  return (ok and type(v) == 'table') and #v or 0
end

local function formatAop()
  local aop = safeCall(function() return exports['nex-hud']:getAop() end)
  if type(aop) == 'string' and aop ~= '' then return aop end
  if type(aop) == 'table' then
    local parts = {}
    for _, v in pairs(aop) do parts[#parts + 1] = tostring(v) end
    if #parts > 0 then return table.concat(parts, ', ') end
  end
  return 'Statewide'
end

local function formatPriority()
  local pr = safeCall(function() return exports['nex-hud']:getPriority() end)
  if type(pr) == 'string' and pr ~= '' then return pr end
  if type(pr) == 'table' then
    local lines = {}
    for k, v in pairs(pr) do
      if type(v) == 'table' then
        local state = v.state or v.priority or v.status or v.name or 'Available'
        lines[#lines + 1] = ('%s: %s'):format(tostring(k), tostring(state))
      else
        lines[#lines + 1] = ('%s: %s'):format(tostring(k), tostring(v))
      end
    end
    if #lines > 0 then return table.concat(lines, '\n') end
  end
  return 'Available'
end

-- ---- embed ---------------------------------------------------------------
local function buildEmbed()
  local nPlayers = #GetPlayers()
  local staffCount, roster = staffOnline()
  local leo  = countUnits(FLRP_STATUS.LeoEntities)
  local fire = countUnits(FLRP_STATUS.FireEntities)
  local hasFire = #FLRP_STATUS.FireEntities > 0
  local total = leo + (hasFire and fire or 0)

  local duty = ('LEO: **%d**'):format(leo)
  if hasFire then duty = duty .. ('\nFire/EMS: **%d**'):format(fire) end
  duty = duty .. ('\nTotal: **%d**'):format(total)

  local fields = {
    { name = 'Server Status',    value = '🟢 Online',                                   inline = true },
    { name = 'Players Online',   value = ('`%d / %d`'):format(nPlayers, maxPlayers()),  inline = true },
    { name = 'Staff In-Game',    value = ('`%d`'):format(staffCount),                   inline = true },
    { name = 'Current AOP',      value = formatAop(),                                   inline = false },
    { name = 'Priority Status',  value = formatPriority(),                              inline = false },
    { name = 'Vehicles Spawned', value = ('`%d`'):format(vehicleCount()),               inline = true },
    { name = 'Personnel On Duty', value = duty,                                         inline = true },
  }
  if JOIN_URL ~= '' then
    fields[#fields + 1] = { name = 'Join Server', value = ('[%s](%s)'):format(FLRP_STATUS.JoinLabel, JOIN_URL), inline = false }
  end
  local rosterText = (#roster > 0) and table.concat(roster, '\n') or '*None online*'
  if #rosterText > 1000 then rosterText = rosterText:sub(1, 1000) .. '\n…' end
  fields[#fields + 1] = { name = ('Staff Personnel (%d)'):format(staffCount), value = rosterText, inline = false }

  return {
    title     = 'Server Information',
    color     = FLRP_STATUS.Color,
    thumbnail = (FLRP_STATUS.Thumbnail ~= '') and { url = FLRP_STATUS.Thumbnail } or nil,
    fields    = fields,
    footer    = { text = ('%s • auto-updates every %ds'):format(FLRP_STATUS.ServerName, FLRP_STATUS.UpdateSeconds) },
    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
  }
end

local function payload()
  return json.encode({ username = FLRP_STATUS.Username, embeds = { buildEmbed() } })
end

-- ---- post / edit ---------------------------------------------------------
local function postNew()
  local base = webhookBase(); if not base then return end
  PerformHttpRequest(base .. '?wait=true', function(status, body)
    if (status == 200 or status == 204) and body and body ~= '' then
      local ok, data = pcall(json.decode, body)
      if ok and data and data.id then
        msgId = data.id
        SetResourceKvp('flrp_status_msg', msgId)
      end
    else
      print(('[flrp_status] post failed: HTTP %s %s'):format(tostring(status), tostring(body)))
    end
  end, 'POST', payload(), { ['Content-Type'] = 'application/json' })
end

local function editExisting()
  local base = webhookBase(); if not base or not msgId then return postNew() end
  PerformHttpRequest(base .. '/messages/' .. msgId, function(status, body)
    if status == 404 then          -- message was deleted; repost
      msgId = nil
      DeleteResourceKvp('flrp_status_msg')
      postNew()
    elseif status ~= 200 and status ~= 204 then
      print(('[flrp_status] edit failed: HTTP %s %s'):format(tostring(status), tostring(body)))
    end
  end, 'PATCH', payload(), { ['Content-Type'] = 'application/json' })
end

-- ---- loop ----------------------------------------------------------------
CreateThread(function()
  Wait(4000)
  refreshConvars()
  if not webhookBase() then
    print('[flrp_status] flrp_status_webhook not set — status embed disabled.')
    return
  end
  msgId = GetResourceKvpString('flrp_status_msg')
  if not msgId or msgId == '' then msgId = nil end

  while true do
    refreshConvars()
    if not debugged then -- log the raw AOP/priority shapes once, for tuning
      debugged = true
      print('[flrp_status] getAop -> ' .. json.encode(safeCall(function() return exports['nex-hud']:getAop() end)))
      print('[flrp_status] getPriority -> ' .. json.encode(safeCall(function() return exports['nex-hud']:getPriority() end)))
    end
    if msgId then editExisting() else postNew() end
    Wait(FLRP_STATUS.UpdateSeconds * 1000)
  end
end)
