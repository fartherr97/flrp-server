-- ==========================================================================
-- FLRP :: flrp_jail/server.lua — Jail Manager + Hospitalize (authoritative)
-- ==========================================================================

local ready = false

local function isStaff(src) return IsPlayerAceAllowed(src, FLRP_JAIL.StaffAce) end
local function isLeo(src)   return IsPlayerAceAllowed(src, FLRP_JAIL.LeoAce) end
local function name(src)    return GetPlayerName(src) or ('Player ' .. src) end

local function licenseOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'license:' then return id end
  end
  return nil
end
local function discordOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'discord:' then return id:sub(9) end
  end
  return nil
end
local function srcByLicense(lic)
  for _, pid in ipairs(GetPlayers()) do
    if licenseOf(tonumber(pid)) == lic then return tonumber(pid) end
  end
  return nil
end

-- ---- db ------------------------------------------------------------------
CreateThread(function()
  while not FLRP.DB.IsReady() do Wait(500) end
  FLRP.DB.Update([[CREATE TABLE IF NOT EXISTS `jail_stats` (
    `license` VARCHAR(64) NOT NULL PRIMARY KEY, `total` INT NOT NULL DEFAULT 0)]])
  FLRP.DB.Update([[CREATE TABLE IF NOT EXISTS `jail_active` (
    `license` VARCHAR(64) NOT NULL PRIMARY KEY, `until_ts` BIGINT NOT NULL, `seconds` INT NOT NULL DEFAULT 0)]])
  ready = true
  print('[flrp_jail] ready.')
end)

local function totalJails(lic)
  if not lic then return 0 end
  return tonumber(FLRP.DB.Scalar('SELECT `total` FROM `jail_stats` WHERE `license` = ?', { lic })) or 0
end
local function activeUntil(lic)
  if not lic then return nil end
  return tonumber(FLRP.DB.Scalar('SELECT `until_ts` FROM `jail_active` WHERE `license` = ?', { lic }))
end

-- ---- penal code -----------------------------------------------------------
local charges = {}

-- Accept either the flrp shape ({charges:[{id,name,class,jailSeconds,fine}]})
-- OR the FLRP website shape (a bare array of {id,code,title,degree,jail,fine}).
local function normalizeCharges(data)
  local list = (type(data) == 'table' and data.charges) or data
  if type(list) ~= 'table' then return nil end
  local out = {}
  for _, e in ipairs(list) do
    if type(e) == 'table' then
      local nm  = e.name or e.title
      local cls = e.class or e.degree or ''
      local secs = tonumber(e.jailSeconds) or tonumber(e.jail) or 0
      local fine = e.fine
      if type(fine) == 'string' then fine = tonumber((fine:gsub('[^%d]', ''))) end
      fine = tonumber(fine) or 0
      if nm then
        out[#out + 1] = { id = e.id or nm, code = e.code or '', name = nm, class = cls, jailSeconds = math.floor(secs), fine = fine }
      end
    end
  end
  return (#out > 0) and out or nil
end

local function loadPenalCode()
  local raw = LoadResourceFile(GetCurrentResourceName(), 'penalcode.json')
  if raw then
    local ok, data = pcall(json.decode, raw)
    if ok then charges = normalizeCharges(data) or {} end
  end
  print(('[flrp_jail] penal code: %d charges from penalcode.json'):format(#charges))
end
loadPenalCode()

local function penalUrl()
  local url = GetConvar(FLRP_JAIL.PenalCodeConvar, '')
  if url == '' or not url:find('^https?://') then return nil end
  return url
end

-- Blocking fetch (awaited) — used by the in-game Refresh button. Returns
-- true if the penal code was updated. Times out at 6s so a hung endpoint
-- never freezes the request.
local function fetchPenalCodeAwait()
  local url = penalUrl(); if not url then return false end
  local p, done = promise.new(), false
  local function finish(v) if not done then done = true; p:resolve(v) end end
  PerformHttpRequest(url, function(status, body)
    if status == 200 and body and body ~= '' then
      local ok, data = pcall(json.decode, body)
      local norm = ok and normalizeCharges(data)
      if norm then charges = norm; return finish(true) end
    end
    print(('[flrp_jail] penal code fetch failed (HTTP %s / bad shape).'):format(tostring(status)))
    finish(false)
  end, 'GET', '', { ['Accept'] = 'application/json' })
  SetTimeout(6000, function() finish(false) end)
  return Citizen.Await(p)
end

-- Startup fetch + periodic auto-poll so on-site edits flow in on their own.
CreateThread(function()
  if not penalUrl() then return end
  Wait(3000)
  if fetchPenalCodeAwait() then print(('[flrp_jail] penal code synced (%d charges).'):format(#charges)) end
  local mins = tonumber(FLRP_JAIL.PenalRefreshMins) or 0
  if mins <= 0 then return end
  while true do
    Wait(mins * 60000)
    fetchPenalCodeAwait()
  end
end)

local function injurySeconds(id)
  for _, i in ipairs(FLRP_JAIL.Injuries) do if i.id == id then return i.seconds end end
  for _, i in ipairs(FLRP_JAIL.Injuries) do if i.id == FLRP_JAIL.DefaultInjury then return i.seconds end end
  return 240
end

-- ---- views ---------------------------------------------------------------
local function playerList()
  local list = {}
  for _, pid in ipairs(GetPlayers()) do
    pid = tonumber(pid)
    local lic = licenseOf(pid)
    local until_ts = activeUntil(lic)
    list[#list + 1] = {
      id      = pid,
      name    = name(pid),
      discord = discordOf(pid) or '',
      total   = totalJails(lic),
      jailed  = (until_ts ~= nil and until_ts > os.time()),
    }
  end
  table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  return list
end

local function stateFor(src)
  return {
    ok        = true,
    perms     = { jail = isStaff(src), hospitalize = isStaff(src), leoHospitalize = isLeo(src) or isStaff(src) },
    players   = playerList(),
    hospitals = FLRP_JAIL.Hospitals,
    injuries  = FLRP_JAIL.Injuries,
    charges   = charges,
    logo      = GetConvar('flrp_reports_logo', FLRP_JAIL.Logo),
    serverName= FLRP_JAIL.ServerName,
    maxSeconds= FLRP_JAIL.MaxSeconds,
    defaultSeconds  = FLRP_JAIL.DefaultSeconds,
    defaultInjury   = FLRP_JAIL.DefaultInjury,
    leoHospSeconds  = FLRP_JAIL.LeoHospSeconds,
  }
end

local function hospitalById(id)
  for _, h in ipairs(FLRP_JAIL.Hospitals) do if h.id == id then return h end end
  return FLRP_JAIL.Hospitals[1]
end

-- ---- actions -------------------------------------------------------------
local H = {}

function H.state(src) return stateFor(src) end

-- In-game Refresh button: force an immediate re-pull of the penal code, then
-- return fresh state (players + latest charges). No-ops the fetch if no URL.
function H.refreshPenal(src)
  fetchPenalCodeAwait()
  return stateFor(src)
end

function H.jail(src, p)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local target = tonumber(p.id or 0)
  if not target or not GetPlayerName(target) then return { ok = false, error = 'Player not online.' } end
  local secs = math.max(1, math.min(FLRP_JAIL.MaxSeconds, math.floor(tonumber(p.seconds or 0) or 0)))
  local lic = licenseOf(target)
  if not lic then return { ok = false, error = 'Could not read that player\'s license.' } end
  local until_ts = os.time() + secs
  FLRP.DB.Update('INSERT INTO `jail_active` (`license`,`until_ts`,`seconds`) VALUES (?,?,?) ' ..
    'ON DUPLICATE KEY UPDATE `until_ts`=VALUES(`until_ts`), `seconds`=VALUES(`seconds`)', { lic, until_ts, secs })
  FLRP.DB.Update('INSERT INTO `jail_stats` (`license`,`total`) VALUES (?,1) ' ..
    'ON DUPLICATE KEY UPDATE `total`=`total`+1', { lic })
  TriggerClientEvent('flrp_jail:enter', target, {
    untilTs = until_ts, cell = FLRP_JAIL.Cell, release = FLRP_JAIL.Release,
  })
  TriggerClientEvent('flrp_notify:toast', target, { title = 'Jail', kind = 'error',
    body = ('You have been jailed for %d seconds.'):format(secs) })
  pcall(function() exports.flrp_logs:Send('jail', { player = src,
    description = ('%s jailed %s for %ds'):format(name(src), name(target), secs) }) end)
  return { ok = true }
end

local function doHospitalize(src, target, hospitalId, secs, tag)
  local h = hospitalById(hospitalId)
  local until_ts = os.time() + secs
  TriggerClientEvent('flrp_jail:hospitalize', target, {
    untilTs = until_ts, coords = h.coords, label = h.label,
  })
  TriggerClientEvent('flrp_notify:toast', target, { title = 'Hospital', kind = 'info',
    body = ('You were hospitalized at %s for %d seconds.'):format(h.label, secs) })
  pcall(function() exports.flrp_logs:Send('jail', { player = src, title = 'HOSPITALIZE',
    description = ('%s %s %s -> %s (%ds)'):format(name(src), tag, name(target), h.label, secs) }) end)
end

function H.hospitalize(src, p)
  if not isStaff(src) then return { ok = false, error = 'Staff only.' } end
  local target = tonumber(p.id or 0)
  if not target or not GetPlayerName(target) then return { ok = false, error = 'Player not online.' } end
  doHospitalize(src, target, p.hospital, injurySeconds(tostring(p.injury or FLRP_JAIL.DefaultInjury)), 'hospitalized')
  return { ok = true }
end

function H.leoHospitalize(src, p)
  if not (isLeo(src) or isStaff(src)) then return { ok = false, error = 'LEO only.' } end
  local target = tonumber(p.id or 0)
  if not target or not GetPlayerName(target) then return { ok = false, error = 'Player not online.' } end
  if FLRP_JAIL.LeoHospTargetLeo and not isStaff(src) and not isLeo(target) then
    return { ok = false, error = 'LEO Hospitalize is for other LEO only.' }
  end
  doHospitalize(src, target, p.hospital, FLRP_JAIL.LeoHospSeconds, 'LEO-hospitalized')
  return { ok = true }
end

-- ---- release + persistence -----------------------------------------------
local function release(lic, target)
  FLRP.DB.Update('DELETE FROM `jail_active` WHERE `license` = ?', { lic })
  if target then TriggerClientEvent('flrp_jail:release', target) end
end

-- Client says it's spawned in — re-apply an active jail after a relog.
RegisterNetEvent('flrp_jail:ready', function()
  local src = source
  local lic = licenseOf(src); if not lic then return end
  local until_ts = activeUntil(lic)
  if until_ts and until_ts > os.time() then
    TriggerClientEvent('flrp_jail:enter', src, { untilTs = until_ts, cell = FLRP_JAIL.Cell, release = FLRP_JAIL.Release })
  elseif until_ts then
    release(lic, nil)   -- expired while offline
  end
end)

-- Authoritative expiry sweep — releases anyone whose time is up.
CreateThread(function()
  while true do
    Wait(5000)
    if ready then
      local now = os.time()
      local rows = FLRP.DB.Query('SELECT `license` FROM `jail_active` WHERE `until_ts` <= ?', { now }) or {}
      for _, r in ipairs(rows) do
        release(r.license, srcByLicense(r.license))
      end
    end
  end
end)

-- ---- bridge --------------------------------------------------------------
RegisterNetEvent('flrp_jail:req', function(action, payload, reqId)
  local src = source
  if type(src) ~= 'number' or src <= 0 then return end
  payload = type(payload) == 'table' and payload or {}
  local res
  if not ready then
    res = { ok = false, error = 'Jail system starting — try again in a moment.' }
  else
    local h = H[tostring(action)]
    if not h or (action ~= 'state' and not (isStaff(src) or isLeo(src))) then
      res = { ok = false, error = 'Not allowed.' }
    else
      local ok, r = pcall(h, src, payload)
      if ok and type(r) == 'table' then res = r
      else print(('[flrp_jail] handler %s failed: %s'):format(tostring(action), tostring(r))); res = { ok = false, error = 'Server error.' } end
    end
  end
  TriggerClientEvent('flrp_jail:res', src, reqId, res)
end)
