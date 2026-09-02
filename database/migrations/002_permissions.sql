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
