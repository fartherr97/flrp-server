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
