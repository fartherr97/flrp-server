-- ==========================================================================
-- FLRP :: flrp_interact/server/main.lua — manifest + advert broadcasting
-- ==========================================================================
-- Answers the client's per-player manifest (ACE-gated category visibility +
-- the donator vehicles they may spawn) and handles the two advert actions,
-- each authoritatively re-checked here (never trust the client's menu).
-- ==========================================================================

local Ads       = FLRP_INTERACT.Ads
local lastCivAd = {}  -- [license] = os.time()
local lastLeoAd = {}

local function licenseOf(src)
  for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
    if id:sub(1, 8) == 'license:' then return id end
  end
  return 'src:' .. src
end

-- Donator vehicles this player may spawn, from the flrp_vehicles registry.
local function donatorVehicles(src)
  local ok, list = pcall(function() return exports.flrp_vehicles:ListForPlayer(src) end)
  if not ok or type(list) ~= 'table' then return {} end
  local want = {}
  for _, c in ipairs(FLRP_INTERACT.DonatorVehicleCategories) do want[tostring(c):lower()] = true end
  local out = {}
  for _, v in ipairs(list) do
    if v.category and want[tostring(v.category):lower()] then
      out[#out + 1] = v
    end
  end
  return out
end

-- Sanitise advert text: strip chat colour codes + control chars, cap length.
local function clean(text)
  text = tostring(text or ''):gsub('%^%d', ''):gsub('[%c]', ' '):gsub('%s+', ' ')
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  if #text > Ads.MaxLength then text = text:sub(1, Ads.MaxLength) end
  return text
end

local function broadcast(label, color, text)
  TriggerClientEvent('chat:addMessage', -1, { color = color, multiline = true, args = { label, text } })
  print(('[flrp_interact] (%s) %s'):format(label, text))
end

-- ---- actions -------------------------------------------------------------
local H = {}

function H.open(src)
  return {
    leo     = IsPlayerAceAllowed(src, 'flrp.leo'),
    donator = IsPlayerAceAllowed(src, FLRP_INTERACT.DonatorAce) or false,
    vehicles = donatorVehicles(src),
  }
end

function H.civAd(src, p)
  local lic = licenseOf(src)
  local now = os.time()
  local last = lastCivAd[lic]
  if last and (now - last) < Ads.CivCooldown then
    return { ok = false, error = ('Wait %ds before advertising again.'):format(Ads.CivCooldown - (now - last)) }
  end
  local text = clean(p.text)
  if #text < 3 then return { ok = false, error = 'Advertisement too short.' } end
  lastCivAd[lic] = now
  broadcast(Ads.CivLabel, Ads.CivColor, text)
  pcall(function() exports.flrp_logs:Send('chat', { player = src, title = 'ADVERTISEMENT', description = text }) end)
  return { ok = true, msg = 'Advertisement broadcast.' }
end

function H.leoAd(src, p)
  if not IsPlayerAceAllowed(src, 'flrp.leo') then return { ok = false, error = 'Law enforcement only.' } end
  local lic = licenseOf(src)
  local now = os.time()
  local last = lastLeoAd[lic]
  if last and (now - last) < Ads.LeoCooldown then
    return { ok = false, error = ('Wait %ds before another advisory.'):format(Ads.LeoCooldown - (now - last)) }
  end
  local text = clean(p.text)
  if #text < 3 then return { ok = false, error = 'Advisory too short.' } end

  -- Resolve the player's department branding.
  local dept
  for _, d in ipairs(Ads.Depts) do
    if IsPlayerAceAllowed(src, d.ace) then dept = d; break end
  end
  local label = dept and (dept.label .. ' ' .. Ads.LeoLabelSuffix) or ('LEO ' .. Ads.LeoLabelSuffix)
  local color = dept and dept.color or { 241, 196, 15 }

  lastLeoAd[lic] = now
  broadcast(('🚔 %s'):format(label), color, text)
  pcall(function() exports.flrp_logs:Send('staffchat', { player = src, title = label, description = text }) end)
  return { ok = true, msg = 'Advisory broadcast.' }
end

-- ---- bridge --------------------------------------------------------------
RegisterNetEvent('flrp_interact:req', function(action, payload, reqId)
  local src = source
  if type(src) ~= 'number' or src <= 0 then return end
  payload = type(payload) == 'table' and payload or {}
  local h = H[tostring(action)]
  local res
  if not h then
    res = { ok = false, error = 'Unknown action.' }
  else
    local ok, r = pcall(h, src, payload)
    if ok then res = r
    else
      print(('[flrp_interact] handler %s failed: %s'):format(tostring(action), tostring(r)))
      res = { ok = false, error = 'Server error.' }
    end
  end
  TriggerClientEvent('flrp_interact:res', src, reqId, res)
end)

AddEventHandler('playerDropped', function()
  -- cooldown tables are keyed by license, harmless to leave; nothing to clear.
end)
