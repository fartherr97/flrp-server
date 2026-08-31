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
