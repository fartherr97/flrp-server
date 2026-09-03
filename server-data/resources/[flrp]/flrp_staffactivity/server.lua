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

-- Tier label IS the group heading. Order/grouping come from FLRP_STAFF.RankTiers.
local function groupForRank(label)
  for _, t in ipairs(FLRP_STAFF.RankTiers) do if t.label == label then return label end end
  return FLRP_STAFF.UnknownGroup
end

local function rankOrder(label)
  for i, t in ipairs(FLRP_STAFF.RankTiers) do if t.label == label then return i end end
  return #FLRP_STAFF.RankTiers + 1
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

-- transient on-screen toast (never enters chat history)
local function notify(src, title, body, kind)
  if type(src) == 'number' and src > 0 then
    TriggerClientEvent('flrp_notify:toast', src, { title = title, body = body, kind = kind or 'info' })
  end
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
  notify(src, 'STAFF VEST', on and 'You are now ON the clock (vest on).' or 'You are now OFF the clock (vest off).', on and 'ok' or 'info')
end

for _, cmd in ipairs({ 'vest', 'sd' }) do
  RegisterCommand(cmd, function(src)
    if type(src) ~= 'number' or src <= 0 then return end
    if not IsPlayerAceAllowed(src, FLRP_STAFF.VestAce) then
      notify(src, 'STAFF VEST', 'Staff only.', 'error')
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

-- ---- Discord staff roster (authoritative) --------------------------------
local discordRoster, discordRosterAt = nil, 0   -- { [discordId] = { name, rank } }
local rosterWarned = false

local function staffRoles()   -- flat, highest-first: { {id, label}, ... } (first match wins)
  local out = {}
  for _, t in ipairs(FLRP_STAFF.RankTiers) do
    for _, id in ipairs(t.ids or {}) do
      if id and id ~= '' then out[#out + 1] = { id = tostring(id), label = t.label } end
    end
  end
  return out
end

-- Pages through /guilds/{id}/members (1000/page) and keeps members holding a
-- staff role. cb(rosterTable) on success, cb(nil, err) on failure.
local function fetchDiscordRoster(cb)
  local token = GetConvar('flrp_discord_token', '')
  local guild = GetConvar('flrp_discord_guild_id', '')
  if token == '' or token == 'REPLACE_ME' or guild == '' or guild == 'REPLACE_ME' then
    return cb(nil, 'flrp_discord_token / flrp_discord_guild_id not set')
  end
  local roles = staffRoles()
  if #roles == 0 then return cb(nil, 'no RankTiers role ids configured') end

  local result, after, pages = {}, nil, 0
  local function page()
    pages = pages + 1
    if pages > 25 then return cb(result) end   -- safety cap (25k members)
    local url = ('https://discord.com/api/v10/guilds/%s/members?limit=1000%s'):format(guild, after and ('&after=' .. after) or '')
    PerformHttpRequest(url, function(st, body)
      if st ~= 200 then return cb(nil, 'HTTP ' .. tostring(st) .. (st == 403 and ' (enable the bot\'s Server Members Intent)' or '')) end
      local ok, list = pcall(json.decode, body or '')
      if not ok or type(list) ~= 'table' then return cb(nil, 'bad response') end
      for _, m in ipairs(list) do
        local u = m.user or {}
        local rank
        for _, r in ipairs(roles) do
          for _, rid in ipairs(m.roles or {}) do
            if tostring(rid) == r.id then rank = r.label; break end
          end
          if rank then break end
        end
        if rank and u.id then
          result[tostring(u.id)] = { name = m.nick or u.global_name or u.username or ('User ' .. tostring(u.id)), rank = rank }
        end
        if u.id then after = tostring(u.id) end
      end
      if #list >= 1000 and after then page() else cb(result) end
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token })
  end
  page()
end

-- Make sure the roster cache is fresh (<= RefreshMinutes old), then continue.
local function withRoster(cb)
  if discordRoster and (os.time() - discordRosterAt) < (FLRP_STAFF.RefreshMinutes * 60) then return cb() end
  fetchDiscordRoster(function(r, err)
    if r then
      discordRoster, discordRosterAt = r, os.time()
      local n = 0; for _ in pairs(r) do n = n + 1 end
      print(('[flrp_staffactivity] Discord roster: %d staff'):format(n))
    elseif not rosterWarned then
      rosterWarned = true
      print('[flrp_staffactivity] Discord roster unavailable (' .. tostring(err) .. ') — listing staff who have connected instead')
    end
    cb()
  end)
end

-- ---- tracker build -------------------------------------------------------
-- Returns { key -> { name, rank, discord, claims, vest } } for [from, to].
-- Every Discord staff member is present (0s if inactive); claims/vest are
-- joined through staff_members (license <-> discord_id, captured on connect).
local function gather(from, to)
  local now = os.time()
  local staff, byLicense = {}, {}
  local dbMembers = FLRP.DB.Query('SELECT `license`, `name`, `rank`, `discord_id` FROM `staff_members`') or {}
  local licByDiscord = {}
  for _, m in ipairs(dbMembers) do if m.discord_id and m.discord_id ~= '' then licByDiscord[tostring(m.discord_id)] = m.license end end

  -- 1) the roster: Discord (everyone with a staff role) or, if unavailable, the DB
  if discordRoster then
    for did, info in pairs(discordRoster) do
      local e = { name = info.name, rank = info.rank, discord = did, claims = 0, vest = 0, license = licByDiscord[did] }
      staff[did] = e
      if e.license then byLicense[e.license] = e end
    end
  else
    for _, m in ipairs(dbMembers) do
      local e = { name = m.name, rank = m.rank, discord = m.discord_id, claims = 0, vest = 0, license = m.license }
      staff[(m.discord_id and m.discord_id ~= '') and tostring(m.discord_id) or ('lic:' .. m.license)] = e
      byLicense[m.license] = e
    end
  end

  -- activity rows keyed by license -> roster entry (create one if it's someone off-roster)
  local function slot(lic, name)
    local e = byLicense[lic]
    if e then return e end
    -- Discord roster is authoritative: activity from anyone NOT holding a listed
    -- staff role is ignored in the per-person list (still counted in totals).
    if discordRoster then return { claims = 0, vest = 0 } end
    e = { name = name, claims = 0, vest = 0, license = lic }
    for _, m in ipairs(dbMembers) do
      if m.license == lic then e.rank, e.discord = m.rank, m.discord_id; break end
    end
    staff['lic:' .. tostring(lic)] = e; byLicense[lic] = e
    return e
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
  for _, st in pairs(staff) do
    local L = st.license
    st.rank    = st.rank    or (L and onlineRank[L])    or FLRP_STAFF.UnknownGroup
    st.discord = st.discord or (L and onlineDiscord[L])
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

-- o = { titleFrom, titleTo, final }  (stats always cover [from, to])
local function buildEmbed(from, to, o)
  o = o or {}
  local staff = gather(from, to)
  local ov = overall(from, to)

  local totalStaff = 0
  local byGroup, names = {}, {}
  for _, st in pairs(staff) do totalStaff = totalStaff + 1; names[#names + 1] = st end

  table.sort(names, function(a, b)
    local ra, rb = rankOrder(a.rank), rankOrder(b.rank)
    if ra ~= rb then return ra < rb end
    if a.claims ~= b.claims then return a.claims > b.claims end
    return (a.name or '') < (b.name or '')
  end)
  for _, st in ipairs(names) do
    local g = groupForRank(st.rank)
    byGroup[g] = byGroup[g] or {}
    local who = (st.discord and st.discord ~= '') and ('<@' .. st.discord .. '>') or ('**' .. (st.name or 'Unknown') .. '**')
    table.insert(byGroup[g], ('%s: %d claim%s (%s)'):format(who, st.claims, st.claims == 1 and '' or 's', human(st.vest)))
  end

  local desc = ('**Overall Statistics**\n'
    .. 'Total Staff: **%d**\nTotal Reports: **%d**\nTotal Claims: **%d**\n'
    .. 'Attempted Self-Claims: **%d**\nTotal Vest Time: **%s**')
    :format(totalStaff, ov.reports, ov.claims, ov.selfClaims, human(ov.vest))

  local order, seen = {}, {}
  for _, t in ipairs(FLRP_STAFF.RankTiers) do if not seen[t.label] then seen[t.label] = true; order[#order + 1] = t.label end end
  if not seen[FLRP_STAFF.UnknownGroup] then order[#order + 1] = FLRP_STAFF.UnknownGroup end

  local fields = {}
  for _, g in ipairs(order) do
    local lines = byGroup[g]
    if lines and #lines > 0 then
      local chunk, first, len = {}, true, 0
      local function flush()
        if #chunk == 0 then return end
        fields[#fields + 1] = { name = first and g or (g .. ' (cont.)'), value = table.concat(chunk, '\n'), inline = false }
        chunk = {}; first = false; len = 0
      end
      for _, line in ipairs(lines) do
        if len + #line + 1 > 1000 then flush() end
        chunk[#chunk + 1] = line; len = len + #line + 1
      end
      flush()
    end
  end
  if #fields == 0 then
    fields[#fields + 1] = { name = 'No activity', value = '*No claims or vest time recorded in this period.*', inline = false }
  end

  return {
    title       = ('Staff Activity Tracker (%s - %s)'):format(fmtDate(o.titleFrom or from), fmtDate(o.titleTo or to)),
    description = desc,
    color       = FLRP_STAFF.Colour,
    thumbnail   = { url = GetConvar('flrp_reports_logo', FLRP_STAFF.Logo) },
    fields      = fields,
    footer      = { text = FLRP_STAFF.ServerName .. ' • Staff Activity • ' .. (o.final and 'Final' or 'Live') },
    timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
  }
end

-- ---- cycles --------------------------------------------------------------
local ANCHOR, CYCLE = 0, FLRP_STAFF.CycleDays * 86400

-- UTC-midnight epoch for the configured date regardless of server timezone.
local function initAnchor()
  local c = FLRP_STAFF.CycleStart
  local utcOffset = os.time() - os.time(os.date('!*t'))
  ANCHOR = os.time({ year = c.year, month = c.month, day = c.day, hour = 0, min = 0, sec = 0 }) + utcOffset
end
local function cycleIndex(ts) return math.floor((ts - ANCHOR) / CYCLE) end
local function cycleBounds(idx) local st = ANCHOR + idx * CYCLE; return st, st + CYCLE end

-- ---- webhook (post once, then edit in place) ------------------------------
local function webhookBase()
  local url = GetConvar(FLRP_STAFF.WebhookConvar, '')
  if url == '' or not url:find('discord') then return nil end
  return (url:gsub('%?.*$', ''))
end

local HDR = { ['Content-Type'] = 'application/json' }

-- cb(ok, infoOrMsgId). msgId=nil -> POST (returns new id); msgId -> PATCH.
local function send(embed, msgId, cb)
  local base = webhookBase()
  if not base then return cb(false, 'no webhook') end
  local payload = json.encode({ username = FLRP_STAFF.Username, embeds = { embed } })
  if msgId then
    PerformHttpRequest(base .. '/messages/' .. msgId, function(st, body)
      if st == 404 then cb(false, 'gone')
      elseif st == 200 or st == 204 then cb(true, msgId)
      else print(('[flrp_staffactivity] edit failed: HTTP %s %s'):format(tostring(st), tostring(body))); cb(false, st) end
    end, 'PATCH', payload, HDR)
  else
    PerformHttpRequest(base .. '?wait=true', function(st, body)
      if st == 200 or st == 204 then
        local ok, d = pcall(json.decode, body or '')
        cb(true, (ok and type(d) == 'table' and d.id) or nil)
      else print(('[flrp_staffactivity] post failed: HTTP %s %s'):format(tostring(st), tostring(body))); cb(false, st) end
    end, 'POST', payload, HDR)
  end
end

-- Render cycle `idx` into ITS live message (create if missing, else edit).
-- A cycle whose end has passed renders as Final (archived).
local function renderCycle(idx, cb, _retried)
  if not _retried then return withRoster(function() renderCycle(idx, cb, 'rostered') end) end
  if _retried == 'rostered' then _retried = false end
  local now = os.time()
  local st, en = cycleBounds(idx)
  local kv = 'flrp_staffactivity_msg_' .. tostring(idx)
  local msgId = GetResourceKvpString(kv); if msgId == '' then msgId = nil end
  local ok, embed = pcall(buildEmbed, st, math.min(now, en), { titleFrom = st, titleTo = en, final = now >= en })
  if not ok then print('[flrp_staffactivity] build failed: ' .. tostring(embed)); return cb(false, 'build') end
  send(embed, msgId, function(good, info)
    if good then
      if info and not msgId then SetResourceKvp(kv, tostring(info)) end
      cb(true, idx)
    elseif info == 'gone' and not _retried then
      DeleteResourceKvp(kv)              -- message was deleted in Discord; repost it
      renderCycle(idx, cb, true)
    else cb(false, info) end
  end)
end

-- One-off post (never edited): used by /staffactivity last and ad-hoc ranges.
local function postOnce(from, to, o, cb)
  return withRoster(function()
  local ok, embed = pcall(buildEmbed, from, to, o)
  if not ok then print('[flrp_staffactivity] build failed: ' .. tostring(embed)); return cb(false, 'build') end
  send(embed, nil, cb)
  end)
end

-- ---- command -------------------------------------------------------------
local function reason(info)
  return ({ ['no webhook'] = 'no webhook set (full server restart after editing secrets.cfg?)',
            ['build'] = 'internal build error (check console)' })[info] or ('Discord HTTP ' .. tostring(info))
end

RegisterCommand('staffactivity', function(src, args)
  if type(src) == 'number' and src > 0 and not IsPlayerAceAllowed(src, FLRP_STAFF.ManageAce) then
    notify(src, 'STAFF ACTIVITY', 'Directors only.', 'error')
    return
  end
  local function reply(good, msg, info)
    notify(src, 'STAFF ACTIVITY', good and msg or ('Failed: ' .. reason(info)), good and 'ok' or 'error')
    print(('[flrp_staffactivity] %s -> %s%s'):format(msg, tostring(good), good and '' or (' (' .. tostring(info) .. ')')))
  end

  local a = (args and args[1] or ''):lower()
  local now = os.time()
  if a == 'last' or a == 'previous' or a == 'prev' then
    local idx = cycleIndex(now) - 1
    local st, en = cycleBounds(idx)
    postOnce(st, en, { titleFrom = st, titleTo = en, final = true }, function(good, info)
      reply(good, ('Posted last cycle (%s - %s).'):format(fmtDate(st), fmtDate(en)), info)
    end)
  elseif a == '' or a == 'current' or a == 'now' then
    renderCycle(cycleIndex(now), function(good, info)
      local st, en = cycleBounds(cycleIndex(now))
      reply(good, ('Refreshed the live cycle embed (%s - %s).'):format(fmtDate(st), fmtDate(en)), info)
    end)
  else
    local days = tonumber(a)
    if not days then return reply(false, 'usage: /staffactivity [last|current|<days>]', 'usage') end
    days = math.max(1, math.min(days, 365))
    postOnce(now - days * 86400, now, { final = true }, function(good, info)
      reply(good, ('Posted a one-off %d-day tracker.'):format(days), info)
    end)
  end
end, false)

-- ---- boot + live refresh loop ------------------------------------------------
local KV_CYCLE = 'flrp_staffactivity_cycle'
CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  local ok, err = pcall(ensureTables)
  if not ok then print('[flrp_staffactivity] table setup failed: ' .. tostring(err)) end
  initAnchor()

  -- roster: pick up staff who are ALREADY online (no reconnect needed)
  for _, pid in ipairs(GetPlayers()) do
    local src = tonumber(pid)
    if src then pcall(syncMember, src) end
  end

  local st0, en0 = cycleBounds(cycleIndex(os.time()))
  print(('[flrp_staffactivity] ready — cycle %s - %s, live refresh every %dm'):format(fmtDate(st0), fmtDate(en0), FLRP_STAFF.RefreshMinutes))

  local lastIdx = tonumber(GetResourceKvpString(KV_CYCLE) or '')
  while true do
    if webhookBase() then
      local idx = cycleIndex(os.time())
      if lastIdx and idx > lastIdx then
        -- cycle rolled over: stamp the previous one Final (archive), then start the new one
        renderCycle(lastIdx, function(good) if good then print('[flrp_staffactivity] archived cycle ' .. lastIdx) end end)
        Wait(1500)
      end
      renderCycle(idx, function(good)
        if good and idx ~= lastIdx then
          SetResourceKvp(KV_CYCLE, tostring(idx)); lastIdx = idx
          print('[flrp_staffactivity] live cycle embed up (cycle ' .. idx .. ')')
        end
      end)
    end
    Wait(FLRP_STAFF.RefreshMinutes * 60 * 1000)
  end
end)
