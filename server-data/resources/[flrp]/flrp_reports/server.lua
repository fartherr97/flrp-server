-- ==========================================================================
-- FLRP :: flrp_reports/server.lua — report store, claims, messaging, analytics
-- ==========================================================================
-- Working set lives in memory (open + claimed + a short resolved history) and
-- every mutation is written through to MySQL (`reports`, `report_messages`),
-- which is what the analytics leaderboard is computed from. Tables are created
-- automatically on boot (CREATE TABLE IF NOT EXISTS) so no manual migration is
-- needed; database/migrations/010_reports.sql mirrors the schema for the record.
--
-- Client <-> server bridge: the client sends
--   TriggerServerEvent('flrp_reports:req', action, payload, reqId)
-- and gets TriggerClientEvent('flrp_reports:res', reqId, result). Every
-- handler re-checks permissions server-side; nothing trusts the client.
-- ==========================================================================

local ACE      = FLRP_REPORTS.StaffAce
local reports  = {}   -- id -> report
local lastSubmit = {} -- license -> os.time()
local ready    = false

-- ---- helpers -------------------------------------------------------------
local function isStaff(src)
  src = tonumber(src)
  return (src and src > 0 and IsPlayerAceAllowed(src, ACE)) and true or false
end

local function licenseOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'license:' then return id:sub(9) end
  end
  return nil
end

local function srcByLicense(lic)
  if not lic then return nil end
  for _, pid in ipairs(GetPlayers()) do
    local s = tonumber(pid)
    if s and licenseOf(s) == lic then return s end
  end
  return nil
end

local function staffSrcs()
  local t = {}
  for _, pid in ipairs(GetPlayers()) do
    local s = tonumber(pid)
    if s and isStaff(s) then t[#t + 1] = s end
  end
  return t
end

local function catInfo(id)
  for _, c in ipairs(FLRP_REPORTS.Categories) do
    if c.id == id then return c end
  end
  return FLRP_REPORTS.Categories[#FLRP_REPORTS.Categories]
end

local function trim(s, max)
  s = tostring(s or '')
  s = (s:gsub('^%s+', ''))
  s = (s:gsub('%s+$', ''))
  if #s > max then s = s:sub(1, max) end
  return s
end

-- Staff-team Discord role to ping on NEW reports. Read from the convar so the
-- real id lives in secrets.cfg, never in git. Empty / REPLACE_ME = no ping.
local function pingRole()
  local id = GetConvar(FLRP_REPORTS.PingRoleConvar, '')
  if id == '' or id == 'REPLACE_ME' or not id:match('^%d+$') then return nil end
  return id
end

-- extra = { content = 'text above the embed', mentionRoles = { roleId } } (both optional)
local function discord(title, description, src, fields, extra)
  if not FLRP_REPORTS.DiscordLog then return end
  extra = extra or {}
  pcall(function()
    exports.flrp_logs:Send('report', {
      player = src, title = title, description = description, fields = fields,
      content = extra.content, mentionRoles = extra.mentionRoles,
    })
  end)
end

local function toast(src, t)
  if src then TriggerClientEvent('flrp_reports:toast', src, t) end
end

local function refresh(src)
  if src then TriggerClientEvent('flrp_reports:refresh', src) end
end

local function refreshStaff()
  for _, s in ipairs(staffSrcs()) do refresh(s) end
end

-- ---- DB ------------------------------------------------------------------
local function ensureTables()
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `reports` (
      `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `reporter_license`   VARCHAR(64)  NOT NULL,
      `reporter_name`      VARCHAR(100) NOT NULL,
      `target_name`        VARCHAR(100) NULL,
      `category`           VARCHAR(32)  NOT NULL,
      `description`        TEXT         NOT NULL,
      `status`             ENUM('open','claimed','resolved') NOT NULL DEFAULT 'open',
      `claimed_by_license` VARCHAR(64)  NULL,
      `claimed_by_name`    VARCHAR(100) NULL,
      `created_at`         INT UNSIGNED NOT NULL,
      `claimed_at`         INT UNSIGNED NULL,
      `resolved_at`        INT UNSIGNED NULL,
      `resolution`         VARCHAR(255) NULL,
      PRIMARY KEY (`id`),
      KEY `idx_status`   (`status`),
      KEY `idx_reporter` (`reporter_license`),
      KEY `idx_claimer`  (`claimed_by_license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `staff_self_claims` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `license`    VARCHAR(64)  NOT NULL,
      `name`       VARCHAR(100) NOT NULL,
      `report_id`  INT UNSIGNED NOT NULL,
      `created_at` INT UNSIGNED NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
  FLRP.DB.Query([[
    CREATE TABLE IF NOT EXISTS `report_messages` (
      `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `report_id`      INT UNSIGNED NOT NULL,
      `sender_license` VARCHAR(64)  NOT NULL,
      `sender_name`    VARCHAR(100) NOT NULL,
      `is_staff`       TINYINT(1)   NOT NULL DEFAULT 0,
      `body`           TEXT         NOT NULL,
      `created_at`     INT UNSIGNED NOT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_report` (`report_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]])
end

local function loadWorkingSet()
  local rows = FLRP.DB.Query([[
    (SELECT * FROM `reports` WHERE `status` <> 'resolved')
    UNION ALL
    (SELECT * FROM `reports` WHERE `status` = 'resolved' ORDER BY `resolved_at` DESC LIMIT ?)
  ]], { FLRP_REPORTS.ResolvedHistory }) or {}
  reports = {}
  local ids = {}
  for _, r in ipairs(rows) do
    r.messages = {}
    reports[r.id] = r
    ids[#ids + 1] = r.id
  end
  if #ids > 0 then
    local placeholders = string.rep('?,', #ids):sub(1, -2)
    local msgs = FLRP.DB.Query(
      ('SELECT * FROM `report_messages` WHERE `report_id` IN (%s) ORDER BY `id` ASC'):format(placeholders), ids) or {}
    for _, m in ipairs(msgs) do
      local r = reports[m.report_id]
      if r then
        r.messages[#r.messages + 1] = {
          name = m.sender_name, staff = m.is_staff == 1 or m.is_staff == true,
          body = m.body, at = m.created_at,
        }
      end
    end
  end
end

-- Keep the in-memory resolved history bounded.
local function pruneResolved()
  local resolved = {}
  for _, r in pairs(reports) do
    if r.status == 'resolved' then resolved[#resolved + 1] = r end
  end
  table.sort(resolved, function(a, b) return (a.resolved_at or 0) > (b.resolved_at or 0) end)
  for i = FLRP_REPORTS.ResolvedHistory + 1, #resolved do
    reports[resolved[i].id] = nil
  end
end

-- ---- views ---------------------------------------------------------------
local function view(r, viewerSrc)
  local staff = isStaff(viewerSrc)
  local c = catInfo(r.category)
  local reporterSrc = srcByLicense(r.reporter_license)
  return {
    id             = r.id,
    category       = r.category,
    categoryLabel  = c.label,
    categoryColour = c.colour,
    description    = r.description,
    target         = r.target_name,
    status         = r.status,
    reporter       = {
      name   = r.reporter_name,
      src    = staff and reporterSrc or nil,
      online = reporterSrc ~= nil,
    },
    claimedBy      = r.claimed_by_name,
    claimedByMe    = (r.claimed_by_license ~= nil and r.claimed_by_license == licenseOf(viewerSrc)),
    own            = (r.reporter_license == licenseOf(viewerSrc)),
    createdAt      = r.created_at,
    claimedAt      = r.claimed_at,
    resolvedAt     = r.resolved_at,
    resolution     = r.resolution,
    messages       = r.messages,
  }
end

local function stateFor(src)
  local staff = isStaff(src)
  local lic = licenseOf(src)
  local list = {}
  for _, r in pairs(reports) do
    if staff or r.reporter_license == lic then
      list[#list + 1] = view(r, src)
    end
  end
  table.sort(list, function(a, b) return a.createdAt > b.createdAt end)
  return {
    ok           = true,
    isStaff      = staff,
    me           = { src = src, name = GetPlayerName(src) },
    staffOnline  = #staffSrcs(),
    reports      = list,
    categories   = FLRP_REPORTS.Categories,
    logo         = GetConvar('flrp_reports_logo', FLRP_REPORTS.Logo),
    serverName   = FLRP_REPORTS.ServerName,
    key          = FLRP_REPORTS.Key,
    toastSeconds = FLRP_REPORTS.ToastSeconds,
    maxDesc      = FLRP_REPORTS.MaxDescription,
    maxMsg       = FLRP_REPORTS.MaxMessage,
    maxOpen      = FLRP_REPORTS.MaxOpenPerPlayer,
    now          = os.time(),
  }
end

-- ---- actions -------------------------------------------------------------
local H = {}

function H.state(src) return stateFor(src) end

function H.submit(src, p)
  local lic = licenseOf(src)
  if not lic then return { ok = false, error = 'Could not read your license.' } end
  local t = os.time()
  local last = lastSubmit[lic]
  if last and (t - last) < FLRP_REPORTS.CooldownSeconds then
    return { ok = false, error = ('Please wait %ds before submitting another report.'):format(FLRP_REPORTS.CooldownSeconds - (t - last)) }
  end
  local openCount = 0
  for _, r in pairs(reports) do
    if r.reporter_license == lic and r.status ~= 'resolved' then openCount = openCount + 1 end
  end
  if openCount >= FLRP_REPORTS.MaxOpenPerPlayer then
    return { ok = false, error = ('You already have %d open report%s — staff will get to them. You can add details from "My Reports".'):format(openCount, openCount == 1 and '' or 's') }
  end
  local desc = trim(p.description, FLRP_REPORTS.MaxDescription)
  if #desc < 10 then return { ok = false, error = 'Please describe the issue (at least 10 characters).' } end
  local cat    = catInfo(p.category).id
  local target = trim(p.target or '', 100); if target == '' then target = nil end
  local name   = GetPlayerName(src) or ('Player ' .. src)

  local id = FLRP.DB.Insert(
    'INSERT INTO `reports` (`reporter_license`,`reporter_name`,`target_name`,`category`,`description`,`status`,`created_at`) VALUES (?,?,?,?,?,?,?)',
    { lic, name, target, cat, desc, 'open', t })
  if not id then return { ok = false, error = 'Database error — try again in a moment.' } end

  reports[id] = {
    id = id, reporter_license = lic, reporter_name = name, target_name = target,
    category = cat, description = desc, status = 'open', created_at = t, messages = {},
  }
  lastSubmit[lic] = t

  local label = catInfo(cat).label
  for _, s in ipairs(staffSrcs()) do
    toast(s, { kind = 'new', title = ('New Report #%d'):format(id), body = label .. ' — ' .. name,
               reportId = id, seconds = FLRP_REPORTS.ToastSeconds })
    refresh(s)
  end
  local role = pingRole()
  discord(('NEW REPORT #%d'):format(id), desc, src, {
    { name = 'Category', value = label, inline = true },
    { name = 'Against',  value = target or '—', inline = true },
    { name = 'Staff online', value = tostring(#staffSrcs()), inline = true },
  }, {
    -- plain text ABOVE the embed: just the staff-team ping (embed carries the rest)
    content      = role and ('<@&' .. role .. '>') or nil,
    mentionRoles = role and { role } or nil,
  })
  return { ok = true, id = id }
end

function H.claim(src, p)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local r = reports[tonumber(p.id or 0)]
  if not r then return { ok = false, error = 'Report not found.' } end
  if r.status ~= 'open' then return { ok = false, error = 'Already ' .. r.status .. (r.claimed_by_name and (' by ' .. r.claimed_by_name) or '') .. '.' } end
  if r.reporter_license == licenseOf(src) then
    pcall(function()
      FLRP.DB.Insert('INSERT INTO `staff_self_claims` (`license`,`name`,`report_id`,`created_at`) VALUES (?,?,?,?)',
        { licenseOf(src) or '', GetPlayerName(src) or 'Unknown', r.id, os.time() })
    end)
    return { ok = false, error = 'You can\'t claim your own report — another staff member has to take it.' }
  end
  local t = os.time()
  r.status, r.claimed_by_license, r.claimed_by_name, r.claimed_at = 'claimed', licenseOf(src), GetPlayerName(src), t
  FLRP.DB.Update('UPDATE `reports` SET `status`=?,`claimed_by_license`=?,`claimed_by_name`=?,`claimed_at`=? WHERE `id`=?',
    { 'claimed', r.claimed_by_license, r.claimed_by_name, t, r.id })
  local rs = srcByLicense(r.reporter_license)
  toast(rs, { kind = 'info', title = ('Report #%d claimed'):format(r.id), body = r.claimed_by_name .. ' is handling your report.', reportId = r.id, seconds = 8 })
  refresh(rs); refreshStaff()
  discord(('REPORT #%d CLAIMED'):format(r.id),
    ('**%s** claimed report **#%d** (from %s) after **%s**.'):format(r.claimed_by_name, r.id, r.reporter_name, FLRP_REPORTS_fmtDur(t - r.created_at)),
    src)  -- no content line = no ping
  return { ok = true }
end

function H.unclaim(src, p)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local r = reports[tonumber(p.id or 0)]
  if not r or r.status ~= 'claimed' then return { ok = false, error = 'Not a claimed report.' } end
  r.status, r.claimed_by_license, r.claimed_by_name, r.claimed_at = 'open', nil, nil, nil
  FLRP.DB.Update('UPDATE `reports` SET `status`=?,`claimed_by_license`=NULL,`claimed_by_name`=NULL,`claimed_at`=NULL WHERE `id`=?', { 'open', r.id })
  refresh(srcByLicense(r.reporter_license)); refreshStaff()
  return { ok = true }
end

function H.resolve(src, p)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local r = reports[tonumber(p.id or 0)]
  if not r or r.status == 'resolved' then return { ok = false, error = 'Report not found or already resolved.' } end
  if r.status == 'open' and r.reporter_license == licenseOf(src) then
    return { ok = false, error = 'You can\'t resolve your own unclaimed report — another staff member has to handle it.' }
  end
  local t = os.time()
  if r.status == 'open' then -- resolving straight from open counts as a claim too
    r.claimed_by_license, r.claimed_by_name, r.claimed_at = licenseOf(src), GetPlayerName(src), t
  end
  r.status, r.resolved_at = 'resolved', t
  r.resolution = trim(p.resolution or '', 255); if r.resolution == '' then r.resolution = nil end
  FLRP.DB.Update('UPDATE `reports` SET `status`=?,`claimed_by_license`=?,`claimed_by_name`=?,`claimed_at`=?,`resolved_at`=?,`resolution`=? WHERE `id`=?',
    { 'resolved', r.claimed_by_license, r.claimed_by_name, r.claimed_at, t, r.resolution, r.id })
  local rs = srcByLicense(r.reporter_license)
  toast(rs, { kind = 'ok', title = ('Report #%d resolved'):format(r.id), body = r.resolution or ('Closed by ' .. (GetPlayerName(src) or 'staff')), reportId = r.id, seconds = 10 })
  refresh(rs); refreshStaff(); pruneResolved()
  discord(('REPORT #%d RESOLVED'):format(r.id), r.resolution or '—', src, {
    { name = 'Reporter', value = r.reporter_name, inline = true },
    { name = 'Handled by', value = r.claimed_by_name or '—', inline = true },
    { name = 'Time to resolve', value = FLRP_REPORTS_fmtDur(t - (r.claimed_at or r.created_at)), inline = true },
  })
  return { ok = true }
end

function H.message(src, p)
  local r = reports[tonumber(p.id or 0)]
  if not r then return { ok = false, error = 'Report not found.' } end
  local staff = isStaff(src)
  local lic = licenseOf(src)
  if not staff and r.reporter_license ~= lic then return { ok = false, error = 'Not your report.' } end
  if r.status == 'resolved' then return { ok = false, error = 'This report is resolved.' } end
  local body = trim(p.body, FLRP_REPORTS.MaxMessage)
  if body == '' then return { ok = false, error = 'Empty message.' } end
  local t = os.time()
  local name = GetPlayerName(src) or 'Unknown'
  FLRP.DB.Insert('INSERT INTO `report_messages` (`report_id`,`sender_license`,`sender_name`,`is_staff`,`body`,`created_at`) VALUES (?,?,?,?,?,?)',
    { r.id, lic or '', name, staff and 1 or 0, body, t })
  r.messages[#r.messages + 1] = { name = name, staff = staff, body = body, at = t }

  if staff then
    local rs = srcByLicense(r.reporter_license)
    toast(rs, { kind = 'msg', title = ('%s · Report #%d'):format(name, r.id), body = body, reportId = r.id, seconds = 10 })
    refresh(rs); refreshStaff()
  else
    -- player replied: ping the claimer if any, else all staff
    local cs = srcByLicense(r.claimed_by_license)
    if cs then
      toast(cs, { kind = 'msg', title = ('%s · Report #%d'):format(name, r.id), body = body, reportId = r.id, seconds = 10 })
    else
      for _, s in ipairs(staffSrcs()) do
        toast(s, { kind = 'msg', title = ('%s · Report #%d'):format(name, r.id), body = body, reportId = r.id, seconds = 8 })
      end
    end
    refreshStaff(); refresh(src)
  end
  return { ok = true }
end

local function teleport(fromSrc, toSrc)
  local ped, tgt = GetPlayerPed(fromSrc), GetPlayerPed(toSrc)
  if not ped or ped == 0 or not tgt or tgt == 0 then return false end
  local c = GetEntityCoords(tgt)
  SetEntityCoords(ped, c.x + 1.0, c.y, c.z, false, false, false, false)
  return true
end

H['goto'] = function(src, p)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local r = reports[tonumber(p.id or 0)]; if not r then return { ok = false, error = 'Report not found.' } end
  local rs = srcByLicense(r.reporter_license)
  if not rs then return { ok = false, error = 'Reporter is not online.' } end
  return { ok = teleport(src, rs) }
end

function H.bring(src, p)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local r = reports[tonumber(p.id or 0)]; if not r then return { ok = false, error = 'Report not found.' } end
  local rs = srcByLicense(r.reporter_license)
  if not rs then return { ok = false, error = 'Reporter is not online.' } end
  toast(rs, { kind = 'info', title = 'Teleported', body = (GetPlayerName(src) or 'Staff') .. ' brought you to them for your report.', seconds = 6 })
  return { ok = teleport(rs, src) }
end

function H.analytics(src)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local staff = FLRP.DB.Query([[
    SELECT `claimed_by_license` AS lic, `claimed_by_name` AS name,
           COUNT(*)                                                     AS claims,
           SUM(`status` = 'resolved')                                   AS resolved,
           AVG(`claimed_at` - `created_at`)                             AS avg_claim,
           MIN(`claimed_at` - `created_at`)                             AS fastest,
           AVG(CASE WHEN `resolved_at` IS NOT NULL THEN `resolved_at` - `claimed_at` END) AS avg_resolve
    FROM `reports`
    WHERE `claimed_at` IS NOT NULL
    GROUP BY `claimed_by_license`, `claimed_by_name`
  ]]) or {}
  local overall = FLRP.DB.Single([[
    SELECT COUNT(*) AS total,
           SUM(`status` = 'resolved') AS resolved,
           AVG(CASE WHEN `claimed_at`  IS NOT NULL THEN `claimed_at`  - `created_at` END) AS avg_claim,
           AVG(CASE WHEN `resolved_at` IS NOT NULL THEN `resolved_at` - `claimed_at` END) AS avg_resolve
    FROM `reports`
  ]]) or {}
  local d = os.date('*t')
  local midnight = os.time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
  local today = FLRP.DB.Single('SELECT COUNT(*) AS n, AVG(`claimed_at` - `created_at`) AS avg_claim FROM `reports` WHERE `created_at` >= ?', { midnight }) or {}
  local resolvedToday = FLRP.DB.Scalar('SELECT COUNT(*) FROM `reports` WHERE `resolved_at` >= ?', { midnight }) or 0
  local open, claimed = 0, 0
  for _, r in pairs(reports) do
    if r.status == 'open' then open = open + 1 elseif r.status == 'claimed' then claimed = claimed + 1 end
  end
  return {
    ok = true, staff = staff, overall = overall,
    today = { reports = today.n or 0, avgClaim = today.avg_claim, resolved = resolvedToday },
    open = open, claimed = claimed, minClaims = FLRP_REPORTS.MinClaimsToRank, now = os.time(),
  }
end

-- ---- bridge --------------------------------------------------------------
RegisterNetEvent('flrp_reports:req', function(action, payload, reqId)
  local src = source
  if type(src) ~= 'number' or src <= 0 then return end
  payload = type(payload) == 'table' and payload or {}
  local res
  if not ready then
    res = { ok = false, error = 'Reports are still starting up — try again in a moment.' }
  else
    local h = H[tostring(action)]
    if not h then
      res = { ok = false, error = 'Unknown action.' }
    else
      local ok, r = pcall(h, src, payload)
      if ok and type(r) == 'table' then res = r
      else
        print(('[flrp_reports] handler %s failed: %s'):format(tostring(action), tostring(r)))
        res = { ok = false, error = 'Server error.' }
      end
    end
  end
  TriggerClientEvent('flrp_reports:res', src, reqId, res)
end)

-- /report and /calladmin open the player form.
for _, cmd in ipairs(FLRP_REPORTS.Commands) do
  RegisterCommand(cmd, function(src)
    if type(src) ~= 'number' or src <= 0 then return end
    TriggerClientEvent('flrp_reports:open', src, 'new')
  end, false)
end

-- Duration formatter shared with the Discord lines (global so H.* can use it).
function FLRP_REPORTS_fmtDur(s)
  s = math.max(0, math.floor(tonumber(s) or 0))
  if s < 60 then return s .. 's' end
  local m = math.floor(s / 60); s = s % 60
  if m < 60 then return ('%dm %02ds'):format(m, s) end
  local h = math.floor(m / 60); m = m % 60
  return ('%dh %02dm'):format(h, m)
end

-- ---- boot ----------------------------------------------------------------
CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  local ok, err = pcall(ensureTables)
  if not ok then print('[flrp_reports] table setup failed: ' .. tostring(err)) end
  local ok2, err2 = pcall(loadWorkingSet)
  if not ok2 then print('[flrp_reports] load failed: ' .. tostring(err2)) end
  ready = true
  local n = 0; for _ in pairs(reports) do n = n + 1 end
  print(('[flrp_reports] ready — %d report(s) in working set'):format(n))
end)
