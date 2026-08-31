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
