-- ==========================================================================
-- FLRP :: flrp_staffactivity/server.lua — vest tracking + activity tracker
-- ==========================================================================

local vest = {}   -- src -> { id = sessionId, startedAt = ts }

-- ---- helpers -------------------------------------------------------------
local function licenseOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'license:' then return id:sub(9) end
  end
  return nil
end

local function discordOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'discord:' then return id:sub(9) end
  end
  return nil
end

local function rankOf(src)
  for _, r in ipairs(FLRP_STAFF.Ranks) do
    if IsPlayerAceAllowed(src, r.ace) then return r.label end
  end
  return nil
end

local function groupForRank(label)
  for _, r in ipairs(FLRP_STAFF.Ranks) do
    if r.label == label then return r.group end
  end
  return FLRP_STAFF.UnknownGroup
end

local function rankOrder(label)
  for i, r in ipairs(FLRP_STAFF.Ranks) do
    if r.label == label then return i end
  end
  return #FLRP_STAFF.Ranks + 1
end

-- "25 minutes", "1 hour", "14 hours", "2 days" — SSRP-style natural duration.
local function human(sec)
  sec = math.floor(tonumber(sec) or 0)
  if sec < 60 then local n = math.max(0, sec); return n .. (n == 1 and ' second' or ' seconds') end
  if sec < 3600 then local n = math.floor(sec / 60); return n .. (n == 1 and ' minute' or ' minutes') end
  if sec < 86400 then local n = math.floor(sec / 3600); return n .. (n == 1 and ' hour' or ' hours') end
  local n = math.floor(sec / 86400); return n .. (n == 1 and ' day' or ' days')
end

local function webhookBase()
  local url = GetConvar(FLRP_STAFF.WebhookConvar, '')
  if url == '' or not url:find('discord') then return nil end
  return url
end

local function upsertMember(lic, name, rank, discordId)
  if not lic or not rank then return end
  pcall(function()
    FLRP.DB.Query([[
      INSERT INTO `staff_members` (`license`,`name`,`rank`,`discord_id`,`last_seen`) VALUES (?,?,?,?,?)
      ON DUPLICATE KEY UPDATE `name`=VALUES(`name`), `rank`=VALUES(`rank`),
        `discord_id`=COALESCE(VALUES(`discord_id`), `discord_id`), `last_seen`=VALUES(`last_seen`)
    ]], { lic, name or 'Unknown', rank, discordId, os.time() })
  end)
end

-- Keep the staff ROSTER current: every staff member is recorded (with rank +
-- Discord id) when they connect, and dropped if they no longer hold a staff
-- rank. This is what lets the tracker list the whole team, 0 claims included.
local function syncMember(src)
  local lic = licenseOf(src); if not lic then return end
  local rank = rankOf(src)
  if rank then
    upsertMember(lic, GetPlayerName(src), rank, discordOf(src))
  else
    pcall(function() FLRP.DB.Update('DELETE FROM `staff_members` WHERE `license` = ?', { lic }) end)
  end
end

AddEventHandler('playerJoining', function()
  local src = source
  CreateThread(function()
    Wait(2000)                              -- principals are attached during the gate; give it a beat
    if GetPlayerName(src) then syncMember(src) end
  end)
end)

-- ---- vest state ----------------------------------------------------------
local function setVest(src, on)
  src = tonumber(src); if not src or not GetPlayerName(src) then return false end
  local lic = licenseOf(src)
  if not lic then return false end
  if on then
    if vest[src] then return true end
    local t = os.time()
    local rank = rankOf(src) or FLRP_STAFF.UnknownGroup
    upsertMember(lic, GetPlayerName(src), rank, discordOf(src))
    local id = FLRP.DB.Insert('INSERT INTO `staff_vest_sessions` (`license`,`name`,`rank`,`started_at`) VALUES (?,?,?,?)',
      { lic, GetPlayerName(src), rank, t })
    vest[src] = { id = id, startedAt = t }
    pcall(function() exports.flrp_dutycounter:SetStaffOnDuty(src, true) end)
  else
    local v = vest[src]; if not v then return true end
    local t = os.time()
    FLRP.DB.Update('UPDATE `staff_vest_sessions` SET `ended_at`=?, `seconds`=? WHERE `id`=?', { t, t - v.startedAt, v.id })
    vest[src] = nil
    pcall(function() exports.flrp_dutycounter:SetStaffOnDuty(src, false) end)
  end
  return true
end

exports('SetVest', function(src, on) return setVest(src, on and true or false) end)
exports('IsOnVest', function(src) return vest[tonumber(src)] ~= nil end)

local function toggleVest(src)
  local on = vest[tonumber(src)] == nil
  setVest(src, on)
  TriggerClientEvent('chat:addMessage', src, {
    color = on and { 0, 191, 196 } or { 150, 160, 170 },
    args  = { 'STAFF VEST', on and 'You are now ON the clock (vest on).' or 'You are now OFF the clock (vest off).' },
  })
end

for _, cmd in ipairs({ 'vest', 'sd' }) do
  RegisterCommand(cmd, function(src)
    if type(src) ~= 'number' or src <= 0 then return end
    if not IsPlayerAceAllowed(src, FLRP_STAFF.VestAce) then
      TriggerClientEvent('chat:addMessage', src, { color = { 200, 60, 60 }, args = { 'SYSTEM', 'Staff only.' } })
      return
    end
    toggleVest(src)
  end, false)
end

AddEventHandler('playerDropped', function()
  local src = source
  if vest[src] then setVest(src, false) end
end)
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for src in pairs(vest) do setVest(src, false) end
end)

-- ---- schema --------------------------------------------------------------
local function ensureTables()
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `staff_vest_sessions` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `license`    VARCHAR(64)  NOT NULL,
      `name`       VARCHAR(100) NOT NULL,
      `rank`       VARCHAR(32)  NOT NULL,
      `started_at` INT UNSIGNED NOT NULL,
      `ended_at`   INT UNSIGNED NULL,
      `seconds`    INT UNSIGNED NULL,
      PRIMARY KEY (`id`),
      KEY `idx_lic`   (`license`),
      KEY `idx_start` (`started_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `staff_members` (
      `license`    VARCHAR(64)  NOT NULL,
      `name`       VARCHAR(100) NOT NULL,
      `rank`       VARCHAR(32)  NOT NULL,
      `discord_id` VARCHAR(32)  NULL,
      `last_seen`  INT UNSIGNED NOT NULL,
      PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  -- tables created before discord_id existed: add the column (MariaDB IF NOT EXISTS)
  pcall(function() FLRP.DB.Query('ALTER TABLE `staff_members` ADD COLUMN IF NOT EXISTS `discord_id` VARCHAR(32) NULL AFTER `rank`') end)
  -- flrp_reports owns these, but create defensively so a query never errors if
  -- this resource boots first.
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `staff_self_claims` (
      `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `license` VARCHAR(64) NOT NULL,
      `name` VARCHAR(100) NOT NULL, `report_id` INT UNSIGNED NOT NULL,
      `created_at` INT UNSIGNED NOT NULL, PRIMARY KEY (`id`), KEY `idx_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  -- close any vest sessions left open by a crash / hard stop (conservative: 0s)
  FLRP.DB.Query('UPDATE `staff_vest_sessions` SET `ended_at`=`started_at`, `seconds`=0 WHERE `ended_at` IS NULL')
end

-- ---- tracker build -------------------------------------------------------
-- Returns { license -> { name, rank, claims, vest } } for [from, to].
local function gather(from, to)
  local now = os.time()
  local staff = {}
  local function slot(lic, name)
    local s = staff[lic]
    if not s then s = { name = name, claims = 0, vest = 0 }; staff[lic] = s
    elseif name and name ~= '' then s.name = name end
    return s
  end

  -- 1) the whole roster first, so every staff member is listed even at 0
  for _, m in ipairs(FLRP.DB.Query('SELECT `license`, `name`, `rank`, `discord_id` FROM `staff_members`') or {}) do
    local st = slot(m.license, m.name)
    st.rank, st.discord = m.rank, m.discord_id
  end

  for _, r in ipairs(FLRP.DB.Query(
    'SELECT `claimed_by_license` lic, `claimed_by_name` name, COUNT(*) claims FROM `reports` WHERE `claimed_at` BETWEEN ? AND ? AND `claimed_by_license` IS NOT NULL GROUP BY `claimed_by_license`, `claimed_by_name`',
    { from, to }) or {}) do
    slot(r.lic, r.name).claims = tonumber(r.claims) or 0
  end

  for _, r in ipairs(FLRP.DB.Query(
    'SELECT `license` lic, `name` name, SUM(COALESCE(`seconds`, ? - `started_at`)) secs FROM `staff_vest_sessions` WHERE `started_at` BETWEEN ? AND ? GROUP BY `license`, `name`',
    { now, from, to }) or {}) do
    slot(r.lic, r.name).vest = tonumber(r.secs) or 0
  end

  -- rank / discord for anyone with activity but not (yet) on the roster
  local onlineRank, onlineDiscord = {}, {}
  for _, pid in ipairs(GetPlayers()) do
    local s = tonumber(pid); local lic = s and licenseOf(s)
    if lic then onlineRank[lic] = rankOf(s); onlineDiscord[lic] = discordOf(s) end
  end
  for lic, s in pairs(staff) do
    s.rank    = s.rank    or onlineRank[lic]    or FLRP_STAFF.UnknownGroup
    s.discord = s.discord or onlineDiscord[lic]
  end
  return staff
end

local function overall(from, to)
  local o = {}
  o.reports    = FLRP.DB.Scalar('SELECT COUNT(*) FROM `reports` WHERE `created_at` BETWEEN ? AND ?', { from, to }) or 0
  o.claims     = FLRP.DB.Scalar('SELECT COUNT(*) FROM `reports` WHERE `claimed_at` BETWEEN ? AND ?', { from, to }) or 0
  o.selfClaims = FLRP.DB.Scalar('SELECT COUNT(*) FROM `staff_self_claims` WHERE `created_at` BETWEEN ? AND ?', { from, to }) or 0
  local vt = FLRP.DB.Scalar('SELECT SUM(COALESCE(`seconds`, ? - `started_at`)) FROM `staff_vest_sessions` WHERE `started_at` BETWEEN ? AND ?', { os.time(), from, to })
  o.vest = tonumber(vt) or 0
  return o
end

local function fmtDate(ts) return os.date('!%B %d, %Y', ts) end

local function buildEmbed(from, to)
  local staff = gather(from, to)
  local o = overall(from, to)

  local totalStaff = 0
  local byGroup = {}   -- group -> { lines }
  local names = {}
  for _, s in pairs(staff) do totalStaff = totalStaff + 1; names[#names + 1] = s end

  -- order staff by rank then claims desc then name
  table.sort(names, function(a, b)
    local ra, rb = rankOrder(a.rank), rankOrder(b.rank)
    if ra ~= rb then return ra < rb end
    if a.claims ~= b.claims then return a.claims > b.claims end
    return (a.name or '') < (b.name or '')
  end)
  for _, s in ipairs(names) do
    local g = groupForRank(s.rank)
    byGroup[g] = byGroup[g] or {}
    local who = (s.discord and s.discord ~= '') and ('<@' .. s.discord .. '>') or ('**' .. (s.name or 'Unknown') .. '**')
    table.insert(byGroup[g], ('%s: %d claim%s (%s)'):format(who, s.claims, s.claims == 1 and '' or 's', human(s.vest)))
  end

  local desc = ('**Overall Statistics**\n'
    .. 'Total Staff: **%d**\nTotal Reports: **%d**\nTotal Claims: **%d**\n'
    .. 'Attempted Self-Claims: **%d**\nTotal Vest Time: **%s**')
    :format(totalStaff, o.reports, o.claims, o.selfClaims, human(o.vest))

  -- ordered group headings: config groups first, then Staff
  local order, seen = {}, {}
  for _, r in ipairs(FLRP_STAFF.Ranks) do if not seen[r.group] then seen[r.group] = true; order[#order + 1] = r.group end end
  if not seen[FLRP_STAFF.UnknownGroup] then order[#order + 1] = FLRP_STAFF.UnknownGroup end

  local fields = {}
  for _, g in ipairs(order) do
    local lines = byGroup[g]
    if lines and #lines > 0 then
      -- split a group across fields if it would exceed Discord's 1024 limit
      local chunk, first = {}, true
      local function flush()
        if #chunk == 0 then return end
        fields[#fields + 1] = { name = first and g or (g .. ' (cont.)'), value = table.concat(chunk, '\n'), inline = false }
        chunk = {}; first = false
      end
      local len = 0
      for _, line in ipairs(lines) do
        if len + #line + 1 > 1000 then flush(); len = 0 end
        chunk[#chunk + 1] = line; len = len + #line + 1
      end
      flush()
    end
  end
  if #fields == 0 then
    fields[#fields + 1] = { name = 'No activity', value = '*No claims or vest time recorded in this period.*', inline = false }
  end

  return {
    title       = ('Staff Activity Tracker (%s - %s)'):format(fmtDate(from), fmtDate(to)),
    description = desc,
    color       = FLRP_STAFF.Colour,
    thumbnail   = { url = GetConvar('flrp_reports_logo', FLRP_STAFF.Logo) },
    fields      = fields,
    footer      = { text = FLRP_STAFF.ServerName .. ' • Staff Activity' },
    timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
  }
end

local function post(from, to, cb)
  local url = webhookBase()
  if not url then if cb then cb(false, 'no webhook') end; return end
  local ok, embed = pcall(buildEmbed, from, to)
  if not ok then print('[flrp_staffactivity] build failed: ' .. tostring(embed)); if cb then cb(false, 'build') end; return end
  PerformHttpRequest(url, function(status, body)
    local good = status == 200 or status == 204
    if not good then print(('[flrp_staffactivity] post failed: HTTP %s %s'):format(tostring(status), tostring(body))) end
    if cb then cb(good, status) end
  end, 'POST', json.encode({ username = FLRP_STAFF.Username, embeds = { embed } }), { ['Content-Type'] = 'application/json' })
end

-- ---- commands ------------------------------------------------------------
RegisterCommand('staffactivity', function(src, args)
  if type(src) == 'number' and src > 0 and not IsPlayerAceAllowed(src, FLRP_STAFF.ManageAce) then
    TriggerClientEvent('chat:addMessage', src, { color = { 200, 60, 60 }, args = { 'SYSTEM', 'Directors only.' } })
    return
  end
  local days = tonumber(args and args[1]) or FLRP_STAFF.PeriodDays
  days = math.max(1, math.min(days, 365))
  local to = os.time(); local from = to - (days * 86400)
  post(from, to, function(good, info)
    local reason = ({ ['no webhook'] = 'no webhook set (full server restart after editing secrets.cfg?)',
                      ['build'] = 'internal build error (check console)' })[info] or ('Discord HTTP ' .. tostring(info))
    if type(src) == 'number' and src > 0 then
      TriggerClientEvent('chat:addMessage', src, { color = good and { 0, 191, 196 } or { 200, 60, 60 },
        args = { 'STAFF ACTIVITY', good and ('Posted the %d-day tracker to Discord.'):format(days) or ('Failed: ' .. reason) } })
    end
    print(('[flrp_staffactivity] manual post %d days -> %s%s'):format(days, tostring(good), good and '' or (' (' .. tostring(info) .. ')')))
  end)
end, false)

-- ---- auto-post + boot ----------------------------------------------------
local KVP = 'flrp_staffactivity_lastpost'
CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  local ok, err = pcall(ensureTables)
  if not ok then print('[flrp_staffactivity] table setup failed: ' .. tostring(err)) end

  -- roster: pick up staff who are ALREADY online (no reconnect needed)
  for _, pid in ipairs(GetPlayers()) do
    local src = tonumber(pid)
    if src then pcall(syncMember, src) end
  end

  if not GetResourceKvpString(KVP) then SetResourceKvp(KVP, tostring(os.time())) end
  print('[flrp_staffactivity] ready (auto-post ' .. (FLRP_STAFF.AutoPost and (FLRP_STAFF.PeriodDays .. 'd') or 'off') .. ')')

  while true do
    Wait(3600 * 1000)   -- check hourly
    if FLRP_STAFF.AutoPost and webhookBase() then
      local last = tonumber(GetResourceKvpString(KVP) or '') or os.time()
      local now = os.time()
      if (now - last) >= (FLRP_STAFF.PeriodDays * 86400) then
        post(last, now, function(good)
          if good then SetResourceKvp(KVP, tostring(now)); print('[flrp_staffactivity] auto-posted tracker') end
        end)
      end
    end
  end
end)
