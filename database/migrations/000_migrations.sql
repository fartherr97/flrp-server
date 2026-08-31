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
