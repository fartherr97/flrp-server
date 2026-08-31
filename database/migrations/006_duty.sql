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
  `department` VARCHAR(16)     NULL,        -- BCSO|FHP|MPD|NULL(civilian)
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
