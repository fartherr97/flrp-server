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
