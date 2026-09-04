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
    logo      = GetConvar('flrp_reports_logo', FLRP_JAIL.Logo),
    serverName= FLRP_JAIL.ServerName,
    maxSeconds= FLRP_JAIL.MaxSeconds,
    defaultSeconds  = FLRP_JAIL.DefaultSeconds,
    hospitalSeconds = FLRP_JAIL.HospitalSeconds,
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
  doHospitalize(src, target, p.hospital, FLRP_JAIL.HospitalSeconds, 'hospitalized')
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
