-- ==========================================================================
-- FLRP :: flrp_status/server.lua — live server-status embed
-- ==========================================================================
-- Posts one embed to the status webhook, then edits that same message every
-- UpdateSeconds so it stays a single live message. AOP/priority come from
-- nex-hud exports; on-duty units from flrp_onduty (via flrp_duty); players/staff/vehicles from
-- server natives.
-- ==========================================================================

local WEBHOOK, JOIN_URL, THUMB = '', '', ''
local msgId = nil
local debugged = false

local function refreshConvars()
  WEBHOOK  = GetConvar(FLRP_STATUS.WebhookConvar, '')
  JOIN_URL = GetConvar(FLRP_STATUS.JoinUrlConvar, '')
  THUMB    = GetConvar(FLRP_STATUS.LogoConvar, FLRP_STATUS.Thumbnail or '')
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

-- ---- unit helpers --------------------------------------------------------
-- Pull a human-readable "callsign — Name" out of a duty roster entry,
-- trying the common field names so it works regardless of exact shape.
local function unitLabel(u)
  if type(u) ~= 'table' then return tostring(u) end
  local name = u.name or u.playerName or u.player_name or u.character
            or u.charName or u.char_name or u.fullname or u.full_name or u.label
  if not name then
    local fn = u.firstname or u.first_name or u.firstName
    local ln = u.lastname  or u.last_name  or u.lastName
    if fn or ln then name = ((fn or '') .. ' ' .. (ln or '')):gsub('^%s+', ''):gsub('%s+$', '') end
  end
  local callsign = u.callsign or u.callSign or u.call_sign or u.badge
                or u.badgeNumber or u.unit or u.unitId or u.unit_id
  if callsign and name then return ('`%s` %s'):format(tostring(callsign), tostring(name)) end
  return tostring(name or callsign or 'Unit')
end

-- Live roster from flrp_onduty's flrp_duty_members table (via flrp_duty), grouped by
-- entity id. Only CONNECTED players count — a stale row for someone who has
-- left never shows.
local function rosterByEntity()
  local ok, roster = pcall(function() return exports.flrp_duty:GetOnDutyRoster() end)
  local by = {}
  if not ok or type(roster) ~= 'table' then return by end
  for _, u in ipairs(roster) do
    if u.online and u.entity then
      by[u.entity] = by[u.entity] or {}
      by[u.entity][#by[u.entity] + 1] = u
    end
  end
  return by
end

-- Build the "Personnel On Duty" text, grouped by department, listing names.
-- Returns (text, totalCount).
local function personnelBlock(depts)
  local by = rosterByEntity()
  local sections, total = {}, 0
  for _, d in ipairs(depts) do
    local units = by[d.id] or {}
    total = total + #units
    if #units > 0 then
      local names = {}
      for _, u in ipairs(units) do names[#names + 1] = '• ' .. unitLabel(u) end
      table.sort(names)
      sections[#sections + 1] = ('**%s (%d)**\n%s'):format(d.label, #units, table.concat(names, '\n'))
    else
      sections[#sections + 1] = ('**%s (0)**'):format(d.label)
    end
  end
  local text = table.concat(sections, '\n')
  if text == '' then text = '*None on duty*' end
  return text, total
end

-- ---- other data sources --------------------------------------------------
local function maxPlayers() return GetConvarInt('sv_maxclients', 64) end

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

-- nex-hud area code -> friendly name (falls back to upper-cased code).
local function areaName(code)
  code = tostring(code or '')
  return FLRP_STATUS.AreaNames[code] or (code ~= '' and code:upper()) or 'Unknown'
end

-- getAop() -> { admin = 'Who', time = <ts>, areas = { 'ss', 'pb', ... } }
local function formatAop()
  local aop = safeCall(function() return exports['nex-hud']:getAop() end)
  if type(aop) == 'table' and type(aop.areas) == 'table' and #aop.areas > 0 then
    local names = {}
    for _, c in ipairs(aop.areas) do names[#names + 1] = areaName(c) end
    return table.concat(names, ', ')
  end
  if type(aop) == 'string' and aop ~= '' then return aop end
  return 'Statewide'
end

-- Map a nex-hud priority `state` string to Available / In-Progress / On Cooldown.
local function stateLabel(state)
  state = tostring(state or 'available'):lower()
  local mapped = FLRP_STATUS.PriorityStateLabels[state]
  if mapped then return mapped end
  if state == '' or state == 'none' then return 'Available' end
  if state:find('cool') then return 'On Cooldown' end
  return 'In-Progress'
end

-- getPriority() -> array of { area = 'bc', state = 'available', indefinite = false, ... }.
-- Show only the configured zones (Broward County + Miami), in config order.
local function formatPriority()
  local pr = safeCall(function() return exports['nex-hud']:getPriority() end)
  local byArea = {}
  if type(pr) == 'table' then
    for _, p in ipairs(pr) do
      if type(p) == 'table' and p.area then byArea[tostring(p.area):lower()] = p end
    end
  end
  local lines = {}
  for _, z in ipairs(FLRP_STATUS.PriorityZones) do
    local p = byArea[z.code]
    lines[#lines + 1] = ('**%s** — %s'):format(z.label, stateLabel(p and p.state))
  end
  return table.concat(lines, '\n')
end

-- ---- embed ---------------------------------------------------------------
local function buildEmbed()
  local nPlayers = #GetPlayers()
  local staffCount, roster = staffOnline()
  local duty, leoTotal = personnelBlock(FLRP_STATUS.LeoDepts)
  local hasFire = #FLRP_STATUS.FireDepts > 0
  local fireBlock, fireTotal = '', 0
  if hasFire then fireBlock, fireTotal = personnelBlock(FLRP_STATUS.FireDepts) end
  local grandTotal = leoTotal + fireTotal

  if #duty > 1000 then duty = duty:sub(1, 1000) .. '\n…' end
  local rosterText = (#roster > 0) and table.concat(roster, '\n') or '*None online*'
  if #rosterText > 1000 then rosterText = rosterText:sub(1, 1000) .. '\n…' end

  local fields = {
    { name = '__Server Status__',   value = '🟢 Online',                                inline = true },
    { name = '__Players Online__',  value = ('`%d / %d`'):format(nPlayers, maxPlayers()), inline = true },
    { name = '__Staff In-Game__',   value = ('`%d`'):format(staffCount),                inline = true },
    { name = '__Current AOP__',     value = formatAop(),                                inline = true },
    { name = '__Vehicles__',        value = ('`%d`'):format(vehicleCount()),            inline = true },
    { name = '__Priority Status__', value = formatPriority(),                           inline = false },
    { name = ('__Law Enforcement On Duty (%d)__'):format(leoTotal), value = duty,       inline = false },
  }
  if hasFire then
    fields[#fields + 1] = { name = ('__Fire / EMS On Duty (%d)__'):format(fireTotal), value = fireBlock, inline = false }
  end
  fields[#fields + 1] = { name = ('__Staff Online (%d)__'):format(staffCount), value = rosterText, inline = false }
  if JOIN_URL ~= '' then
    fields[#fields + 1] = { name = '__Join Server__', value = ('**[%s](%s)**'):format(FLRP_STATUS.JoinLabel, JOIN_URL), inline = false }
  end

  return {
    title       = 'Server Information',
    description  = ('**%d** players online  •  **%d** total personnel on duty'):format(nPlayers, grandTotal),
    color       = FLRP_STATUS.Color,
    thumbnail   = (THUMB ~= '') and { url = THUMB } or nil,
    fields      = fields,
    footer      = { text = ('%s • auto-updates every %ds'):format(FLRP_STATUS.ServerName, FLRP_STATUS.UpdateSeconds) },
    timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
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
    if FLRP_STATUS.Debug and not debugged then -- dump raw shapes once, for mapping
      debugged = true
      print('[flrp_status] getAop -> '      .. json.encode(safeCall(function() return exports['nex-hud']:getAop() end)))
      print('[flrp_status] getPriority -> ' .. json.encode(safeCall(function() return exports['nex-hud']:getPriority() end)))
    end
    if msgId then editExisting() else postNew() end
    Wait(FLRP_STATUS.UpdateSeconds * 1000)
  end
end)
