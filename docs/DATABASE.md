# FLRP Database

Normalized MySQL/MariaDB schema (InnoDB, `utf8mb4`). Money is **integer cents**.
Migrations live in `database/migrations/` and are applied in numeric order;
each is idempotent and records itself in `schema_migrations`.

## Applying migrations

```bash
FLRP_DB_HOST=127.0.0.1 FLRP_DB_USER=flrp FLRP_DB_PASS=secret FLRP_DB_NAME=flrp \
  ./tools/apply_migrations.sh
```

Or run each `*.sql` in order. Re-running is safe.

| File | Contents |
|------|----------|
| `000_migrations.sql` | `schema_migrations` bookkeeping |
| `001_players.sql` | `players`, `player_identifiers` |
| `002_permissions.sql` | `roles`, `permissions`, `role_permissions`, `discord_role_mappings`, `player_roles` |
| `003_economy.sql` | `balances`, `transactions`, `pay_rates` |
| `004_weapons.sql` | `weapons`, `owned_weapons` |
| `005_vehicles.sql` | `vehicles`, `vehicle_permissions` |
| `006_duty.sql` | `player_duty_state`, `player_duty_log` |
| `007_audit_config.sql` | `audit_logs`, `configuration` |
| `008_seed.sql` | roles/permissions/matrix, pay rates, config, DEV weapons |

## Schema overview

```
players ─┬─< player_identifiers
         ├─── balances (1:1)          ─< transactions
         ├─< owned_weapons >─ weapons
         ├─── player_duty_state (1:1) ─< player_duty_log
         └─< player_roles >─ roles ─┬─< role_permissions >─ permissions
                                    ├─< discord_role_mappings
                                    └─── pay_rates (1:1)
vehicles ─< vehicle_permissions
audit_logs        (append-only)
configuration     (runtime key/value)
```

### Key design points

- **Money in cents.** `balances.balance_cents` and `transactions.amount_cents`
  are signed BIGINT. A CHECK enforces non-negative balances.
- **Unique constraints** prevent duplicates: `players.license`,
  `players.discord_id`, `(type, identifier)`, `roles.key`, `permissions.key`,
  `(role_id, permission_id)`, `(discord_role_id, role_id)`,
  `weapons.weapon_name`, `(player_id, weapon_id)`, `vehicles.spawn_name`,
  `transactions.idempotency_key`.
- **Foreign keys** with sensible `ON DELETE` (CASCADE for owned rows, SET NULL
  for optional references like `audit_logs.actor_player_id`).
- **Indexes** on hot lookups (last_seen, category/time, player/time, department
  state, etc.).

## Race-condition safety (money & purchases)

Balance mutations are **server-authoritative** and race-safe:

- **Debit** uses one guarded atomic statement:
  ```sql
  UPDATE balances SET balance_cents = balance_cents - :amt, version = version + 1
  WHERE player_id = :pid AND balance_cents >= :amt;
  ```
  InnoDB row-locks the row for the UPDATE, so concurrent debits serialize and
  can never overdraw. `affectedRows == 0` ⇒ insufficient funds. The matching
  ledger row (with `balance_after_cents`) is written immediately after.
- **Idempotency keys** (`transactions.idempotency_key` UNIQUE) make a
  replayed/duplicated request a no-op that returns the original result.
- **Purchases** additionally rely on `owned_weapons (player_id, weapon_id)`
  UNIQUE and a per-source in-flight lock, so a double-submit cannot double-charge
  or double-grant. If ownership recording fails after a charge, `flrp_gunstores`
  auto-refunds.
- `balances.version` is an optimistic-lock counter (belt-and-suspenders).

All queries are **parameterized** (oxmysql placeholders) — no string
concatenation of user data. See [SECURITY.md](SECURITY.md).

## Append-only tables

`transactions`, `audit_logs`, and `player_duty_log` are append-only in normal
operation. The FLRP Manager API exposes **no** update/delete for `audit_logs`,
so normal admin interfaces cannot rewrite history.

## Configuration table

`configuration` holds runtime-tunable key/value settings (pay interval, starting
balance, feature flags) editable by the FLRP Manager. `flrp_core:GetConfig(key,
default, convar)` reads DB → convar → default.

## Backups

Back up regularly (see [DEPLOYMENT.md](DEPLOYMENT.md)). Critical tables:
`players`, `balances`, `transactions`, `owned_weapons`, `audit_logs`.
