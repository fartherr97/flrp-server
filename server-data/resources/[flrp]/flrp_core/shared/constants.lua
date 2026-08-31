-- ==========================================================================
-- FLRP :: flrp_core/shared/constants.lua
-- ==========================================================================
-- Stable, shared constants used across FLRP resources. These are IDENTIFIERS,
-- not tunable values (tunables live in config/*.cfg and the DB configuration
-- table). Kept in one place so department/role keys never drift.
-- ==========================================================================

FLRP = FLRP or {}
FLRP.Const = {}

-- Authoritative departments. Do NOT add HCSO/TPD or legacy names.
FLRP.Const.Departments = { 'BCSO', 'FHP', 'MPD' }

-- Role keys (must match the `roles.key` column and permissions.cfg groups).
FLRP.Const.Roles = {
  MEMBER        = 'member',
  MODERATOR     = 'moderator',
  ADMINISTRATOR = 'administrator',
  DIRECTOR      = 'director',
  OWNERSHIP     = 'ownership',
  CERT_CIV_1    = 'cert_civ_1',
  CERT_CIV_2    = 'cert_civ_2',
  CERT_CIV_3    = 'cert_civ_3',
  BCSO          = 'bcso',
  FHP           = 'fhp',
  MPD           = 'mpd',
}

-- The three groups permitted to spawn weapons directly through vMenu.
-- Authoritative policy lives in the DB (weapon.vmenu.spawn), but this list is
-- referenced by tooling/docs and as a defensive fallback.
FLRP.Const.VMenuWeaponSpawnRoles = { 'cert_civ_3', 'director', 'ownership' }

-- Transaction types (transactions.type).
FLRP.Const.TxType = {
  PAY          = 'pay',
  PURCHASE     = 'purchase',
  ADMIN_ADJUST = 'admin_adjust',
  REFUND       = 'refund',
  TRANSFER     = 'transfer',
}

-- Audit categories (audit_logs.category).
FLRP.Const.AuditCategory = {
  PERMISSIONS = 'permissions',
  ECONOMY     = 'economy',
  VEHICLES    = 'vehicles',
  WEAPONS     = 'weapons',
  DUTY        = 'duty',
  ROLES       = 'roles',
  ACCESS      = 'access',
}

-- Return true if a string is one of the authoritative departments.
function FLRP.Const.IsDepartment(dept)
  if type(dept) ~= 'string' then return false end
  dept = string.upper(dept)
  for _, d in ipairs(FLRP.Const.Departments) do
    if d == dept then return true end
  end
  return false
end
