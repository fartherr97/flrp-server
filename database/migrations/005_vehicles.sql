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
