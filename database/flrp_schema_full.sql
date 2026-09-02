-- ==========================================================================
-- FLRP :: flrp_schema_full.sql — ALL migrations concatenated, in order.
-- Import this ONE file via Nodecraft Databases (phpMyAdmin / query console).
-- Idempotent + safe to re-run. Generated from database/migrations/*.sql.
-- ==========================================================================

-- ---------------------------------------------------------------------------
-- 000_migrations.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 000_migrations.sql — migration bookkeeping
-- ==========================================================================
-- Tracks which migrations have been applied. Run migrations in numeric order.
-- Every migration is written to be idempotent (IF NOT EXISTS / guarded) so a
-- re-run is safe. See docs/DATABASE.md for how to apply these.
--
-- Engine/charset conventions for ALL FLRP tables:
--   ENGINE=InnoDB (transactions + foreign keys + row locking)
--   DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
-- Money is stored as SIGNED BIGINT in CENTS (never floats). See DATABASE.md.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `schema_migrations` (
  `version`     VARCHAR(64)  NOT NULL,
  `applied_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `description` VARCHAR(255) NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('000', 'migration bookkeeping')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 001_players.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 001_players.sql — player identity + identifiers
-- ==========================================================================
-- The persistent FLRP player record and all of a player's FiveM identifiers.
-- `license` (the FiveM rockstar license) is the primary stable identity.
-- `discord_id` is required for connection (see flrp_access) but stored here
-- for convenience/joins. See docs/DATABASE.md and docs/DISCORD_INTEGRATION.md.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `players` (
  `id`                      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Stable identity: FiveM license WITHOUT the "license:" prefix.
  `license`                 VARCHAR(64)     NOT NULL,
  -- Discord snowflake (numeric string). Nullable only for legacy/import rows.
  `discord_id`              VARCHAR(32)     NULL,
  `name`                    VARCHAR(128)    NULL,
  -- Playtime accounting (seconds). `active_playtime_seconds` is compensated
  -- (non-AFK) time; `total_playtime_seconds` is raw connected time.
  `active_playtime_seconds` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `total_playtime_seconds`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `first_seen`              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen`               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at`              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_players_license` (`license`),
  UNIQUE KEY `uq_players_discord` (`discord_id`),
  KEY `idx_players_last_seen` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- All identifiers FiveM exposes for a player (license, discord, steam, ip,
-- xbl, live, fivem, ...). One row per (type, identifier). Lets us detect
-- alt accounts and resolve a player by any identifier.
CREATE TABLE IF NOT EXISTS `player_identifiers` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_id`   BIGINT UNSIGNED NOT NULL,
  `type`        VARCHAR(16)     NOT NULL,   -- license|discord|steam|ip|xbl|live|fivem
  `identifier`  VARCHAR(128)    NOT NULL,   -- value WITHOUT the "type:" prefix
  `first_seen`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen`   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_identifier` (`type`, `identifier`),
  KEY `idx_pid_player` (`player_id`),
  CONSTRAINT `fk_pid_player`
    FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('001', 'players + player_identifiers')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 002_permissions.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 002_permissions.sql — roles, permissions, mappings
-- ==========================================================================
-- The permission engine's source of truth.
--
--   roles                  FLRP groups (staff / department / certification / base)
--   permissions            every permission string (e.g. weapon.vmenu.spawn)
--   role_permissions       which roles are granted/denied which permissions
--   discord_role_mappings  which Discord role IDs map to which FLRP roles
--   player_roles           explicit per-player role grants (overrides/extra)
--
-- Discord membership decides which roles a player holds at runtime;
-- role_permissions decides what those roles may do. This exactly supports the
-- Owner/Director/Admin/CivIII/BSO/FHP/MPD permission matrix in the FLRP
-- Manager WITHOUT editing Lua. See docs/PERMISSIONS.md.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `roles` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `key`              VARCHAR(64)  NOT NULL,   -- stable handle: ownership, bso, cert_civ_3
  `name`             VARCHAR(128) NOT NULL,   -- display name
  -- kind groups roles for UI + logic: base|staff|department|certification
  `kind`             VARCHAR(24)  NOT NULL DEFAULT 'base',
  -- priority: higher = more authoritative (used for effective role resolution)
  `priority`         INT          NOT NULL DEFAULT 0,
  -- single-parent inheritance (staff chain). NULL = no parent.
  `inherits_role_id` INT UNSIGNED NULL,
  `is_department`    TINYINT(1)   NOT NULL DEFAULT 0,
  `enabled`          TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_roles_key` (`key`),
  KEY `idx_roles_kind` (`kind`),
  CONSTRAINT `fk_roles_inherits`
    FOREIGN KEY (`inherits_role_id`) REFERENCES `roles` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `permissions` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `key`            VARCHAR(128) NOT NULL,   -- e.g. weapon.vmenu.spawn, vehicle.bso.patrol
  `description`    VARCHAR(255) NULL,
  `category`       VARCHAR(48)  NOT NULL DEFAULT 'general', -- weapon|vehicle|economy|staff|...
  -- default_effect applies when NO role grants/denies it to the player.
  `default_effect` ENUM('allow','deny') NOT NULL DEFAULT 'deny',
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_permissions_key` (`key`),
  KEY `idx_permissions_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `role_permissions` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_id`       INT UNSIGNED NOT NULL,
  `permission_id` INT UNSIGNED NOT NULL,
  -- explicit deny beats allow during resolution (see docs/PERMISSIONS.md).
  `effect`        ENUM('allow','deny') NOT NULL DEFAULT 'allow',
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_role_permission` (`role_id`, `permission_id`),
  KEY `idx_rp_permission` (`permission_id`),
  CONSTRAINT `fk_rp_role`
    FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_rp_permission`
    FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `discord_role_mappings` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `discord_role_id` VARCHAR(32)  NOT NULL,   -- Discord role snowflake
  `role_id`         INT UNSIGNED NOT NULL,   -- FLRP role it maps to
  `note`            VARCHAR(255) NULL,
  `enabled`         TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_discord_role_map` (`discord_role_id`, `role_id`),
  KEY `idx_drm_role` (`role_id`),
  CONSTRAINT `fk_drm_role`
    FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Explicit per-player role grants (staff-assigned overrides / extras that are
-- not driven by a Discord role). Optional expiry for temporary grants.
CREATE TABLE IF NOT EXISTS `player_roles` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_id`   BIGINT UNSIGNED NOT NULL,
  `role_id`     INT UNSIGNED    NOT NULL,
  `granted_by`  VARCHAR(64)     NULL,        -- actor identifier
  `expires_at`  TIMESTAMP       NULL,
  `created_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_player_role` (`player_id`, `role_id`),
  KEY `idx_pr_role` (`role_id`),
  CONSTRAINT `fk_pr_player`
    FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_pr_role`
    FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('002', 'roles, permissions, role_permissions, discord_role_mappings, player_roles')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 003_economy.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 003_economy.sql — balances, transactions, pay rates
-- ==========================================================================
-- Persistent money. All amounts are SIGNED BIGINT in CENTS.
--
-- Race-condition safety: balance mutations MUST occur inside a DB transaction
-- that does `SELECT ... FOR UPDATE` on the balances row before updating, and
-- every mutation writes an append-only transactions row recording
-- balance_after_cents. See flrp_economy and docs/DATABASE.md / docs/SECURITY.md.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `balances` (
  `player_id`      BIGINT UNSIGNED NOT NULL,
  `balance_cents`  BIGINT          NOT NULL DEFAULT 0,
  -- optimistic-lock guard (bumped on every write); belt-and-suspenders next
  -- to SELECT ... FOR UPDATE.
  `version`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_id`),
  CONSTRAINT `fk_balances_player`
    FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_balance_nonneg` CHECK (`balance_cents` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Append-only ledger. Never UPDATE/DELETE rows here in normal operation.
CREATE TABLE IF NOT EXISTS `transactions` (
  `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_id`          BIGINT UNSIGNED NOT NULL,
  `amount_cents`       BIGINT          NOT NULL,   -- signed: +credit / -debit
  `balance_after_cents` BIGINT         NOT NULL,   -- snapshot after applying
  `type`               VARCHAR(32)     NOT NULL,   -- pay|purchase|admin_adjust|refund|transfer|...
  `reference`          VARCHAR(128)    NULL,        -- e.g. weapon key, pay-cycle id
  -- Idempotency key to defeat duplicate/replayed requests (e.g. purchases).
  `idempotency_key`    VARCHAR(80)     NULL,
  `metadata`           JSON            NULL,
  `created_at`         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tx_idempotency` (`idempotency_key`),
  KEY `idx_tx_player_time` (`player_id`, `created_at`),
  KEY `idx_tx_type` (`type`),
  CONSTRAINT `fk_tx_player`
    FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Hourly pay per FLRP role. Editable later by the FLRP Manager. Amounts in
-- CENTS per hour; flrp_economy divides by (60 / pay_interval_minutes).
CREATE TABLE IF NOT EXISTS `pay_rates` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_id`      INT UNSIGNED NOT NULL,
  `hourly_cents` BIGINT       NOT NULL DEFAULT 0,
  `enabled`      TINYINT(1)   NOT NULL DEFAULT 1,
  `updated_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pay_rate_role` (`role_id`),
  CONSTRAINT `fk_payrate_role`
    FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('003', 'balances, transactions, pay_rates')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 004_weapons.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 004_weapons.sql — weapon registry + persistent ownership
-- ==========================================================================
-- Centralized weapon registry (source of truth for prices/eligibility) and
-- per-player persistent ownership. Prices are AUTHORITATIVE here: the client
-- may display a price, but flrp_gunstores re-reads it from this table before
-- charging. See docs/WEAPONS.md and docs/SECURITY.md.
--
-- The production catalog is intentionally NOT seeded. Only clearly-labelled
-- DEV/TEST entries are added in 008_seed.sql for validation.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `weapons` (
  `id`                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Canonical GTA/FiveM weapon identifier, e.g. WEAPON_PISTOL (upper-cased).
  `weapon_name`         VARCHAR(64)  NOT NULL,
  `display_name`        VARCHAR(128) NOT NULL,
  `enabled`             TINYINT(1)   NOT NULL DEFAULT 1,
  -- Can this weapon be bought in gun stores?
  `gunstore_available`  TINYINT(1)   NOT NULL DEFAULT 0,
  `price_cents`         BIGINT       NOT NULL DEFAULT 0,   -- authoritative price
  -- Optional certification role required to buy (roles.key), e.g. cert_civ_2.
  `cert_required`       VARCHAR(64)  NULL,
  -- Optional explicit permission required to buy (permissions.key).
  `required_permission` VARCHAR(128) NULL,
  -- Eligible to be spawned via vMenu directly (subject to weapon.vmenu.spawn).
  `vmenu_spawnable`     TINYINT(1)   NOT NULL DEFAULT 0,
  `notes`               VARCHAR(255) NULL,
  `created_at`          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_weapon_name` (`weapon_name`),
  KEY `idx_weapon_store` (`gunstore_available`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Persistent per-player weapon ownership. One row per (player, weapon).
CREATE TABLE IF NOT EXISTS `owned_weapons` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_id`    BIGINT UNSIGNED NOT NULL,
  `weapon_id`    INT UNSIGNED    NOT NULL,
  -- how it was obtained: gunstore|grant|vmenu|import
  `acquired_via` VARCHAR(24)     NOT NULL DEFAULT 'gunstore',
  `acquired_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- links to the purchase transaction (if bought). SET NULL if tx purged.
  `transaction_id` BIGINT UNSIGNED NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_owned_weapon` (`player_id`, `weapon_id`),
  KEY `idx_ow_weapon` (`weapon_id`),
  CONSTRAINT `fk_ow_player`
    FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ow_weapon`
    FOREIGN KEY (`weapon_id`) REFERENCES `weapons` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ow_tx`
    FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('004', 'weapons registry + owned_weapons')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 005_vehicles.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 005_vehicles.sql — vehicle registry + vehicle permissions
-- ==========================================================================
-- Centralized vehicle registry. INTENTIONALLY EMPTY of real FLRP vehicles
-- until asset import (see docs/ASSET_IMPORT.md). The structure supports the
-- future FLRP Manager vehicle UI without touching Lua.
--
--   vehicles             one row per spawnable vehicle
--   vehicle_permissions  optional many-to-many: extra permissions a vehicle
--                        may require beyond `vehicles.required_permission`
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `vehicles` (
  `id`                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- GTA/FiveM spawn name (model), e.g. bso25tahoe. Unique.
  `spawn_name`          VARCHAR(64)  NOT NULL,
  `display_name`        VARCHAR(128) NOT NULL,       -- e.g. "2025 BSO Tahoe"
  -- Owning resource (populated during asset import), e.g. flrp_bso_pack.
  `resource`            VARCHAR(128) NULL,
  -- Department: BSO|FHP|MPD|NULL (civilian).
  `department`          VARCHAR(16)  NULL,
  `category`            VARCHAR(48)  NULL,           -- Patrol|Supervisor|Command|Civilian|...
  -- Minimum department rank required (rank system TBD), e.g. "Deputy".
  `min_rank`            VARCHAR(48)  NULL,
  -- Civilian certification required (roles.key), e.g. cert_civ_2.
  `certification`       VARCHAR(64)  NULL,
  -- Primary permission required to spawn (permissions.key), e.g. vehicle.bso.patrol.
  `required_permission` VARCHAR(128) NULL,
  `enabled`             TINYINT(1)   NOT NULL DEFAULT 1,
  `notes`               VARCHAR(255) NULL,
  `created_at`          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_vehicle_spawn` (`spawn_name`),
  KEY `idx_vehicle_department` (`department`, `enabled`),
  KEY `idx_vehicle_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optional: a vehicle may accept ANY of several permissions (e.g. supervisor
-- OR command). If a vehicle has rows here, flrp_vehicles allows the spawn when
-- the player holds any listed permission OR the primary required_permission.
CREATE TABLE IF NOT EXISTS `vehicle_permissions` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `vehicle_id`     INT UNSIGNED NOT NULL,
  `permission_key` VARCHAR(128) NOT NULL,    -- references permissions.key (logical)
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_vehicle_permission` (`vehicle_id`, `permission_key`),
  KEY `idx_vp_permission` (`permission_key`),
  CONSTRAINT `fk_vp_vehicle`
    FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('005', 'vehicles registry + vehicle_permissions')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 006_duty.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 006_duty.sql — server-authoritative duty state
-- ==========================================================================
-- One current duty state per player. Server-authoritative: a client cannot
-- spoof itself onto a department — flrp_duty verifies the player actually
-- holds the department role before honoring a duty change. See flrp_duty and
-- docs/DEPARTMENTS.md.
--
-- `department` NULL / on_duty=0 means civilian. Duty history is kept in
-- `player_duty_log` for auditing pay eligibility windows.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `player_duty_state` (
  `player_id`  BIGINT UNSIGNED NOT NULL,
  `department` VARCHAR(16)     NULL,        -- BSO|FHP|MPD|NULL(civilian)
  `on_duty`    TINYINT(1)      NOT NULL DEFAULT 0,
  `changed_at` TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                               ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_id`),
  KEY `idx_duty_dept` (`department`, `on_duty`),
  CONSTRAINT `fk_duty_player`
    FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Append-only duty transitions (for pay auditing + accountability).
CREATE TABLE IF NOT EXISTS `player_duty_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_id`  BIGINT UNSIGNED NOT NULL,
  `department` VARCHAR(16)     NULL,
  `on_duty`    TINYINT(1)      NOT NULL,
  `created_at` TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dutylog_player_time` (`player_id`, `created_at`),
  CONSTRAINT `fk_dutylog_player`
    FOREIGN KEY (`player_id`) REFERENCES `players` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('006', 'player_duty_state + player_duty_log')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 007_audit_config.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 007_audit_config.sql — audit log + runtime configuration
-- ==========================================================================
-- `audit_logs`   append-only record of important administrative changes.
--                Normal admin interfaces MUST NOT be able to UPDATE/DELETE
--                these rows (enforced by not exposing such operations in
--                flrp_api + DB grants). See docs/SECURITY.md.
-- `configuration` runtime key/value settings editable by the FLRP Manager
--                (pay interval, feature flags, etc.). flrp_core reads these
--                with convar fallbacks.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Who did it. player_id when resolvable; identifier/discord always recorded.
  `actor_player_id`  BIGINT UNSIGNED NULL,
  `actor_identifier` VARCHAR(128)    NULL,   -- license/api-key/system
  `actor_discord_id` VARCHAR(32)     NULL,
  `category`         VARCHAR(48)     NOT NULL,   -- permissions|economy|vehicles|weapons|duty|roles|...
  `action`           VARCHAR(64)     NOT NULL,   -- create|update|delete|grant|revoke|adjust|...
  `target_type`      VARCHAR(48)     NULL,       -- role|permission|weapon|vehicle|player|...
  `target_id`        VARCHAR(64)     NULL,
  `old_value`        JSON            NULL,
  `new_value`        JSON            NULL,
  `reason`           VARCHAR(255)    NULL,
  `source`           VARCHAR(24)     NOT NULL DEFAULT 'server', -- server|manager|console
  `created_at`       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_category_time` (`category`, `created_at`),
  KEY `idx_audit_actor` (`actor_player_id`),
  KEY `idx_audit_target` (`target_type`, `target_id`),
  CONSTRAINT `fk_audit_actor`
    FOREIGN KEY (`actor_player_id`) REFERENCES `players` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `configuration` (
  `key`         VARCHAR(96)  NOT NULL,
  `value`       TEXT         NULL,
  `value_type`  VARCHAR(16)  NOT NULL DEFAULT 'string', -- string|int|float|bool|json
  `category`    VARCHAR(48)  NOT NULL DEFAULT 'general',
  `description` VARCHAR(255) NULL,
  `updated_by`  VARCHAR(64)  NULL,
  `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                             ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`key`),
  KEY `idx_config_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('007', 'audit_logs + configuration')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 008_seed.sql
-- ---------------------------------------------------------------------------
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
--   * role_permissions matrix (Owner/Director/Admin/CivIII/BSO/FHP/MPD)
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
  ('bso',          'BSO',                    'department',    15, 1),
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

  ('vehicle.bso.patrol',     'Spawn BSO patrol vehicles',              'vehicle', 'deny'),
  ('vehicle.bso.supervisor', 'Spawn BSO supervisor vehicles',          'vehicle', 'deny'),
  ('vehicle.bso.command',    'Spawn BSO command vehicles',             'vehicle', 'deny'),
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
WHERE (r.`key` = 'bso' AND p.`key` = 'vehicle.bso.patrol')
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
  SELECT 'bso',            15000         UNION ALL
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
--   SELECT '<REAL_DISCORD_ROLE_ID>', id, 'BSO'   FROM roles WHERE `key`='bso';
--
-- Or drive mappings from the convars in secrets.cfg via flrp_permissions at
-- boot (recommended). See docs/DISCORD_INTEGRATION.md.

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('008', 'seed roles/permissions/matrix/pay/config/dev-weapons')
ON DUPLICATE KEY UPDATE `version` = `version`;

-- ---------------------------------------------------------------------------
-- 009_seed_vehicles_flrp.sql
-- ---------------------------------------------------------------------------
-- ==========================================================================
-- FLRP :: 009_seed_vehicles_flrp.sql — real imported vehicles (first import)
-- ==========================================================================
-- Populates the `vehicles` registry from the flrp-vehicles content repo
-- (docs/ASSET_INVENTORY.md). These are the REAL spawn names extracted from the
-- packs' vehicles.meta, not guesses:
--   BSO: hcso1a..hcso1h   (repurposed HCSO pack; models spawn as `hcso*`)
--   FHP : hp1a..hp1l, hp2a..hp2p
--   MPD : none imported yet
--
-- NOTE ON ENFORCEMENT: with FLRP built on top of pCore, vMenu vehicle spawning
-- is governed by pCore's configs/vehiclePerms.ts. This registry is the FLRP
-- DB/Manager catalog (source of truth for the website + optional flrp_vehicles
-- enforcement). Keep the two vehicle lists in sync when the fleet changes.
-- Idempotent (ON DUPLICATE KEY UPDATE on unique spawn_name).
-- ==========================================================================

INSERT INTO `vehicles`
  (`spawn_name`,`display_name`,`resource`,`department`,`category`,`required_permission`,`enabled`,`notes`)
VALUES
  ('hcso1a', 'BSO Unit (hcso1a)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1b', 'BSO Unit (hcso1b)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1c', 'BSO Unit (hcso1c)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1d', 'BSO Unit (hcso1d)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1e', 'BSO Unit (hcso1e)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1f', 'BSO Unit (hcso1f)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1g', 'BSO Unit (hcso1g)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1h', 'BSO Unit (hcso1h)', 'HCSO21-24PPVSUVs', 'BSO', 'Patrol', 'vehicle.bso.patrol', 1, 'Imported BSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hp1a', 'FHP Charger (hp1a)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1b', 'FHP Charger (hp1b)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1c', 'FHP Charger (hp1c)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1d', 'FHP Charger (hp1d)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1e', 'FHP Charger (hp1e)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1f', 'FHP Charger (hp1f)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1g', 'FHP Charger (hp1g)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1h', 'FHP Charger (hp1h)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1i', 'FHP Charger (hp1i)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1j', 'FHP Charger (hp1j)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1k', 'FHP Charger (hp1k)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1l', 'FHP Charger (hp1l)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp2a', 'FHP Pursuit SUV (hp2a)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2b', 'FHP Pursuit SUV (hp2b)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2c', 'FHP Pursuit SUV (hp2c)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2d', 'FHP Pursuit SUV (hp2d)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2e', 'FHP Pursuit SUV (hp2e)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2f', 'FHP Pursuit SUV (hp2f)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2g', 'FHP Pursuit SUV (hp2g)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2h', 'FHP Pursuit SUV (hp2h)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2i', 'FHP Pursuit SUV (hp2i)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2j', 'FHP Pursuit SUV (hp2j)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2k', 'FHP Pursuit SUV (hp2k)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2l', 'FHP Pursuit SUV (hp2l)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2m', 'FHP Pursuit SUV (hp2m)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2n', 'FHP Pursuit SUV (hp2n)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2o', 'FHP Pursuit SUV (hp2o)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2p', 'FHP Pursuit SUV (hp2p)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery')
ON DUPLICATE KEY UPDATE `display_name`=VALUES(`display_name`),
  `resource`=VALUES(`resource`), `department`=VALUES(`department`),
  `category`=VALUES(`category`), `required_permission`=VALUES(`required_permission`),
  `enabled`=VALUES(`enabled`), `notes`=VALUES(`notes`);

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('009', 'seed real imported BSO/FHP vehicles')
ON DUPLICATE KEY UPDATE `version` = `version`;

