-- ==========================================================================
-- FLRP :: flrp_weapons/server/registry.lua — weapon registry cache
-- ==========================================================================
-- In-memory cache of the `weapons` table. The DB is the source of truth
-- (editable by the FLRP Manager). Prices read here are AUTHORITATIVE — the
-- client's displayed price is never trusted. See docs/SECURITY.md.
-- ==========================================================================

FLRPW = FLRPW or {}
FLRPW.Registry = { byName = {}, loaded = false }

-- Weapon names are normalized UPPERCASE (matches GTA identifiers).
local function norm(name)
  if type(name) ~= 'string' then return nil end
  return string.upper(name)
end
FLRPW.Registry.Normalize = norm

function FLRPW.Registry.Load()
  if not FLRP.DB.IsReady() then return false end
  local rows = FLRP.DB.Query('SELECT * FROM `weapons`') or {}
  local map = {}
  for _, w in ipairs(rows) do
    map[norm(w.weapon_name)] = {
      id = w.id,
      weaponName = norm(w.weapon_name),
      displayName = w.display_name,
      enabled = w.enabled == 1,
      gunstoreAvailable = w.gunstore_available == 1,
      priceCents = tonumber(w.price_cents) or 0,
      certRequired = w.cert_required,          -- roles.key or nil
      requiredPermission = w.required_permission, -- permissions.key or nil
      vmenuSpawnable = w.vmenu_spawnable == 1,
      notes = w.notes,
    }
  end
  FLRPW.Registry.byName = map
  FLRPW.Registry.loaded = true
  FLRP.Logger.Info('weapons', 'Weapon registry loaded', {
    count = (function() local n=0 for _ in pairs(map) do n=n+1 end return n end)() })
  return true
end

function FLRPW.Registry.Get(weaponName)
  return FLRPW.Registry.byName[norm(weaponName)]
end

-- The gun store catalog: enabled + gunstore_available weapons. This is safe to
-- send to clients for DISPLAY (prices shown are informational; the server
-- re-validates the authoritative price at purchase time).
function FLRPW.Registry.StoreCatalog()
  local out = {}
  for _, w in pairs(FLRPW.Registry.byName) do
    if w.enabled and w.gunstoreAvailable then
      out[#out + 1] = {
        weaponName = w.weaponName,
        displayName = w.displayName,
        priceCents = w.priceCents,
        certRequired = w.certRequired,
        requiredPermission = w.requiredPermission,
      }
    end
  end
  table.sort(out, function(a, b) return a.displayName < b.displayName end)
  return out
end
