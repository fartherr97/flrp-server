-- ==========================================================================
-- FLRP :: 008_seed.sql — base roles, permissions, matrix, dev defaults
-- ==========================================================================
-- Seeds the STABLE base data the permission engine and economy need. All
-- rows here are idempotent (INSERT IGNORE / ON DUPLICATE KEY UPDATE) so the
-- migration can be re-run safely.
--
-- WHAT IS SEEDED:
--   * roles (base / staff / certification / department)
--   * permission strings (weapon / vehicle / staff / economy)
--   * role_permissions matrix (Owner/Director/Admin/CivIII/BCSO/FHP/MPD)
--   * pay_rates (DEV DEFAULTS — subject to change)
--   * configuration defaults
--   * clearly-labelled DEV/TEST weapon entries (remove before production)
--
-- WHAT IS **NOT** SEEDED (must be filled with REAL data, not invented):
--   * discord_role_mappings — needs real Discord role IDs (see bottom).
--   * production weapon catalog — added at asset import.
--   * vehicles — empty until asset import (docs/ASSET_IMPORT.md).
-- ==========================================================================

-- --------------------------------------------------------------------------
-- ROLES
-- --------------------------------------------------------------------------
INSERT INTO `roles` (`key`, `name`, `kind`, `priority`, `is_department`) VALUES
  ('member',        'Community Member',        'base',          0,  0),
  ('moderator',     'Moderator',               'staff',         10, 0),
  ('administrator', 'Administrator',           'staff',         20, 0),
  ('director',      'Director',                'staff',         30, 0),
  ('ownership',     'Ownership',               'staff',         40, 0),
  ('cert_civ_1',    'Certified Civilian I',    'certification', 5,  0),
  ('cert_civ_2',    'Certified Civilian II',   'certification', 6,  0),
  ('cert_civ_3',    'Certified Civilian III',  'certification', 7,  0),
  ('bcso',          'BCSO',                    'department',    15, 1),
  ('fhp',           'FHP',                     'department',    15, 1),
  ('mpd',           'MPD',                     'department',    15, 1)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `kind` = VALUES(`kind`),
  `priority` = VALUES(`priority`), `is_department` = VALUES(`is_department`);

-- Staff inheritance chain: moderator -> administrator -> director -> ownership.
UPDATE `roles` SET `inherits_role_id` =
  (SELECT id FROM (SELECT id, `key` FROM `roles`) t WHERE t.`key` = 'member')
  WHERE `key` = 'moderator';
UPDATE `roles` SET `inherits_role_id` =
  (SELECT id FROM (SELECT id, `key` FROM `roles`) t WHERE t.`key` = 'moderator')
  WHERE `key` = 'administrator';
UPDATE `roles` SET `inherits_role_id` =
  (SELECT id FROM (SELECT id, `key` FROM `roles`) t WHERE t.`key` = 'administrator')
  WHERE `key` = 'director';
UPDATE `roles` SET `inherits_role_id` =
  (SELECT id FROM (SELECT id, `key` FROM `roles`) t WHERE t.`key` = 'director')
  WHERE `key` = 'ownership';

-- --------------------------------------------------------------------------
-- PERMISSIONS
-- --------------------------------------------------------------------------
INSERT INTO `permissions` (`key`, `description`, `category`, `default_effect`) VALUES
  ('weapon.vmenu.spawn',      'Spawn weapons directly via vMenu',        'weapon',  'deny'),
  ('weapon.gunstore.purchase','Purchase weapons at gun stores',          'weapon',  'deny'),

  ('vehicle.bcso.patrol',     'Spawn BCSO patrol vehicles',              'vehicle', 'deny'),
  ('vehicle.bcso.supervisor', 'Spawn BCSO supervisor vehicles',          'vehicle', 'deny'),
  ('vehicle.bcso.command',    'Spawn BCSO command vehicles',             'vehicle', 'deny'),
  ('vehicle.fhp.patrol',      'Spawn FHP patrol vehicles',               'vehicle', 'deny'),
  ('vehicle.fhp.supervisor',  'Spawn FHP supervisor vehicles',           'vehicle', 'deny'),
  ('vehicle.fhp.command',     'Spawn FHP command vehicles',              'vehicle', 'deny'),
  ('vehicle.mpd.patrol',      'Spawn MPD patrol vehicles',               'vehicle', 'deny'),
  ('vehicle.mpd.supervisor',  'Spawn MPD supervisor vehicles',           'vehicle', 'deny'),
  ('vehicle.mpd.command',     'Spawn MPD command vehicles',              'vehicle', 'deny'),
  ('vehicle.civilian.cert1',  'Spawn Cert Civ I vehicles',               'vehicle', 'deny'),
  ('vehicle.civilian.cert2',  'Spawn Cert Civ II vehicles',              'vehicle', 'deny'),
  ('vehicle.civilian.cert3',  'Spawn Cert Civ III vehicles',             'vehicle', 'deny'),

  ('staff.noclip',            'Use staff noclip',                        'staff',   'deny'),
  ('staff.manage.players',    'Manage online players (kick/mod)',        'staff',   'deny'),

  ('economy.manage',          'Manage economy settings + balances',      'economy', 'deny'),
  ('permissions.manage',      'Manage roles/permissions',                'staff',   'deny'),
  ('vehicles.manage',         'Manage vehicle registry',                 'staff',   'deny'),
  ('weapons.manage',          'Manage weapon registry',                  'staff',   'deny')
ON DUPLICATE KEY UPDATE `description` = VALUES(`description`),
  `category` = VALUES(`category`), `default_effect` = VALUES(`default_effect`);

-- --------------------------------------------------------------------------
-- ROLE ↔ PERMISSION MATRIX
-- --------------------------------------------------------------------------
-- Helper pattern: grant (role.key, permission.key). Inheritance is resolved
-- at runtime (a role inherits its parent's grants), so granting to `director`
-- also applies to `ownership`, and granting to `moderator` applies up the
-- whole staff chain. We therefore grant at the LOWEST role that should have it.
--
-- Weapon vMenu spawn policy (authoritative):
--   YES: ownership, director, cert_civ_3   |   NO: everyone else
--   Note: administrator does NOT inherit director's grants (inheritance flows
--   upward: director inherits administrator, not vice-versa), so admins are
--   correctly denied weapon.vmenu.spawn.

-- weapon.vmenu.spawn -> director (=> ownership) + cert_civ_3
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`, `effect`)
SELECT r.id, p.id, 'allow' FROM `roles` r JOIN `permissions` p
WHERE p.`key` = 'weapon.vmenu.spawn' AND r.`key` IN ('director', 'cert_civ_3');

-- weapon.gunstore.purchase -> member (everyone verified may attempt a purchase,
-- still subject to per-weapon cert/permission checks server-side)
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`, `effect`)
SELECT r.id, p.id, 'allow' FROM `roles` r JOIN `permissions` p
WHERE p.`key` = 'weapon.gunstore.purchase' AND r.`key` = 'member';

-- Department base patrol vehicles -> the department role itself.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`, `effect`)
SELECT r.id, p.id, 'allow' FROM `roles` r JOIN `permissions` p
WHERE (r.`key` = 'bcso' AND p.`key` = 'vehicle.bcso.patrol')
   OR (r.`key` = 'fhp'  AND p.`key` = 'vehicle.fhp.patrol')
   OR (r.`key` = 'mpd'  AND p.`key` = 'vehicle.mpd.patrol');

-- Civilian cert vehicles -> the matching certification role (cascading:
-- cert_civ_3 should also get cert1/cert2 tiers; grant explicitly for clarity).
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`, `effect`)
SELECT r.id, p.id, 'allow' FROM `roles` r JOIN `permissions` p
WHERE (r.`key` = 'cert_civ_1' AND p.`key` = 'vehicle.civilian.cert1')
   OR (r.`key` = 'cert_civ_2' AND p.`key` IN ('vehicle.civilian.cert1','vehicle.civilian.cert2'))
   OR (r.`key` = 'cert_civ_3' AND p.`key` IN ('vehicle.civilian.cert1','vehicle.civilian.cert2','vehicle.civilian.cert3'));

-- Director (=> ownership) can spawn ALL department + civilian vehicles (mgmt).
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`, `effect`)
SELECT r.id, p.id, 'allow' FROM `roles` r JOIN `permissions` p
WHERE r.`key` = 'director' AND p.`category` = 'vehicle';

-- Staff capabilities.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`, `effect`)
SELECT r.id, p.id, 'allow' FROM `roles` r JOIN `permissions` p
WHERE (r.`key` = 'moderator'     AND p.`key` IN ('staff.noclip','staff.manage.players'))
   OR (r.`key` = 'director'      AND p.`key` IN ('economy.manage','permissions.manage','vehicles.manage','weapons.manage'));

-- --------------------------------------------------------------------------
-- PAY RATES (DEV DEFAULTS — cents/hour — SUBJECT TO CHANGE)
-- --------------------------------------------------------------------------
INSERT INTO `pay_rates` (`role_id`, `hourly_cents`, `enabled`)
SELECT r.id, x.cents, 1 FROM `roles` r JOIN (
  SELECT 'member'     AS k, 5000   AS cents UNION ALL
  SELECT 'cert_civ_1',      7500          UNION ALL
  SELECT 'cert_civ_2',      10000         UNION ALL
  SELECT 'cert_civ_3',      12500         UNION ALL
  SELECT 'bcso',            15000         UNION ALL
  SELECT 'fhp',             15000         UNION ALL
  SELECT 'mpd',             15000
) x ON x.k = r.`key`
ON DUPLICATE KEY UPDATE `hourly_cents` = VALUES(`hourly_cents`);

-- --------------------------------------------------------------------------
-- CONFIGURATION DEFAULTS (runtime source of truth; convar = fallback)
-- --------------------------------------------------------------------------
INSERT INTO `configuration` (`key`, `value`, `value_type`, `category`, `description`) VALUES
  ('economy.pay_interval_minutes', '15',   'int',  'economy', 'Minutes of active time per pay cycle (DEV DEFAULT)'),
  ('economy.starting_balance_cents','50000','int', 'economy', 'New player starting balance in cents (DEV DEFAULT)'),
  ('economy.afk_timeout_seconds',  '300',  'int',  'economy', 'Seconds of no input before AFK (not compensated)'),
  ('economy.pay_requires_active',  'true', 'bool', 'economy', 'Only pay actively-playing players'),
  ('vehicles.enforce_permissions', 'true', 'bool', 'vehicles','Server-side vehicle permission enforcement'),
  ('weapons.vmenu_policy',         'restricted','string','weapons','vMenu weapon spawn is restricted to weapon.vmenu.spawn holders')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), `value_type` = VALUES(`value_type`),
  `category` = VALUES(`category`), `description` = VALUES(`description`);

-- --------------------------------------------------------------------------
-- DEV/TEST WEAPONS (clearly labelled — REMOVE before production)
-- --------------------------------------------------------------------------
-- Minimal entries so the gun store + registry can be validated end-to-end.
-- These are NOT the production catalog.
INSERT INTO `weapons`
  (`weapon_name`, `display_name`, `enabled`, `gunstore_available`, `price_cents`,
   `cert_required`, `required_permission`, `vmenu_spawnable`, `notes`)
VALUES
  ('WEAPON_PISTOL', '[DEV] Pistol',   1, 1, 25000, NULL,        NULL, 1, 'DEV/TEST — remove before production'),
  ('WEAPON_KNIFE',  '[DEV] Knife',    1, 1, 1000,  NULL,        NULL, 1, 'DEV/TEST — remove before production'),
  ('WEAPON_CARBINERIFLE','[DEV] Carbine',1,1,150000,'cert_civ_2',NULL,1, 'DEV/TEST — cert-gated example; remove before production')
ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`),
  `price_cents` = VALUES(`price_cents`), `notes` = VALUES(`notes`);

-- --------------------------------------------------------------------------
-- DISCORD ROLE MAPPINGS — **NOT SEEDED** (needs REAL Discord role IDs)
-- --------------------------------------------------------------------------
-- Do NOT invent Discord IDs. Once you have the real role IDs, insert like:
--
--   INSERT INTO discord_role_mappings (discord_role_id, role_id, note)
--   SELECT '<REAL_DISCORD_ROLE_ID>', id, 'BCSO'   FROM roles WHERE `key`='bcso';
--
-- Or drive mappings from the convars in secrets.cfg via flrp_permissions at
-- boot (recommended). See docs/DISCORD_INTEGRATION.md.

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('008', 'seed roles/permissions/matrix/pay/config/dev-weapons')
ON DUPLICATE KEY UPDATE `version` = `version`;
