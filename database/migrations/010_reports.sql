-- ==========================================================================
-- FLRP :: 010_reports.sql — staff report system (flrp_reports)
-- ==========================================================================
-- NOTE: flrp_reports creates these tables itself on boot (CREATE TABLE IF NOT
-- EXISTS), so this file is a mirror for the record / fresh-DB setups. Times are
-- unix seconds (INT) so the analytics maths (claimed_at - created_at) is
-- timezone-safe.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS `reports` (
  `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `reporter_license`   VARCHAR(64)  NOT NULL,
  `reporter_name`      VARCHAR(100) NOT NULL,
  `target_name`        VARCHAR(100) NULL,
  `category`           VARCHAR(32)  NOT NULL,
  `description`        TEXT         NOT NULL,
  `status`             ENUM('open','claimed','resolved') NOT NULL DEFAULT 'open',
  `claimed_by_license` VARCHAR(64)  NULL,
  `claimed_by_name`    VARCHAR(100) NULL,
  `created_at`         INT UNSIGNED NOT NULL,
  `claimed_at`         INT UNSIGNED NULL,
  `resolved_at`        INT UNSIGNED NULL,
  `resolution`         VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  KEY `idx_status`   (`status`),
  KEY `idx_reporter` (`reporter_license`),
  KEY `idx_claimer`  (`claimed_by_license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `report_messages` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `report_id`      INT UNSIGNED NOT NULL,
  `sender_license` VARCHAR(64)  NOT NULL,
  `sender_name`    VARCHAR(100) NOT NULL,
  `is_staff`       TINYINT(1)   NOT NULL DEFAULT 0,
  `body`           TEXT         NOT NULL,
  `created_at`     INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_report` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('010', 'reports, report_messages')
ON DUPLICATE KEY UPDATE `version` = `version`;
