-- ==========================================================================
-- FLRP :: flrp_economy/server/payrates.lua — pay rate cache
-- ==========================================================================
-- Loads pay_rates (roleKey -> hourly cents) into memory. DB is the source of
-- truth (editable by the FLRP Manager); convar values in economy.cfg are only
-- a fallback used when a role has no DB pay_rate row.
-- ==========================================================================

FLRPE = FLRPE or {}
FLRPE.PayRates = { byRoleKey = {}, loaded = false }

-- Convar fallbacks (DEV DEFAULTS in DOLLARS -> convert to cents).
local CONVAR_FALLBACK = {
  member     = 'flrp_pay_hourly_civilian',
  cert_civ_1 = 'flrp_pay_hourly_cert_civ_1',
  cert_civ_2 = 'flrp_pay_hourly_cert_civ_2',
  cert_civ_3 = 'flrp_pay_hourly_cert_civ_3',
  bcso       = 'flrp_pay_hourly_bcso',
  fhp        = 'flrp_pay_hourly_fhp',
  mpd        = 'flrp_pay_hourly_mpd',
}

function FLRPE.PayRates.Load()
  if not FLRP.DB.IsReady() then return false end
  local rows = FLRP.DB.Query([[
    SELECT r.`key` AS role_key, pr.`hourly_cents` AS hourly_cents, pr.`enabled` AS enabled
    FROM `pay_rates` pr JOIN `roles` r ON r.id = pr.role_id
  ]]) or {}
  local map = {}
  for _, row in ipairs(rows) do
    if row.enabled == 1 then map[row.role_key] = tonumber(row.hourly_cents) or 0 end
  end
  FLRPE.PayRates.byRoleKey = map
  FLRPE.PayRates.loaded = true
  FLRP.Logger.Info('economy', 'Pay rates loaded', { roles = (function() local n=0 for _ in pairs(map) do n=n+1 end return n end)() })
  return true
end

-- Hourly cents for a role key, DB first then convar fallback then 0.
function FLRPE.PayRates.HourlyCents(roleKey)
  local v = FLRPE.PayRates.byRoleKey[roleKey]
  if v ~= nil then return v end
  local convar = CONVAR_FALLBACK[roleKey]
  if convar then
    local dollars = tonumber(GetConvar(convar, '0')) or 0
    return math.floor(dollars * 100)
  end
  return 0
end
