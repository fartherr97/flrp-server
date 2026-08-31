# FLRP Economy

A lightweight **persistent** economy (`flrp_economy`). Money only — not an
ESX/QB economy. Provides bank balance, an append-only transaction ledger,
role-based hourly pay distributed in active-time intervals, and anti-AFK
compensated playtime.

> All configured pay values are **development defaults** and are **subject to
> change**. The DB is the runtime source of truth.

## Money model

- Balances are stored as **integer cents** (`balances.balance_cents`, signed
  BIGINT). Never floats.
- Every mutation writes an append-only `transactions` row with
  `balance_after_cents`, a `type`, and a UNIQUE `idempotency_key`.
- Non-negative balance enforced by CHECK + guarded debits.

### Exports

```lua
exports.flrp_economy:GetBalance(source)                 -- cents
exports.flrp_economy:CanAfford(source, cents)           -- bool
exports.flrp_economy:Credit(source, cents, type, ref, meta, idem)  -- ok,bal,txId
exports.flrp_economy:Debit(source, cents, type, ref, meta, idem)   -- ok,bal|err
exports.flrp_economy:AdminAdjust(source, signedCents, reason, actor, idem)
exports.flrp_economy:GetTransactions(source, limit)
exports.flrp_economy:IsActive(source)                   -- bool
exports.flrp_economy:GetActiveSeconds(source)
```

## Race-condition & duplicate safety

- **Debit** is a single guarded atomic UPDATE:
  `UPDATE balances SET balance_cents = balance_cents - ? WHERE player_id = ? AND balance_cents >= ?`.
  InnoDB row-locks the row for the update, so concurrent debits are serialized
  and can never overdraw (`affectedRows == 0` ⇒ insufficient funds).
- **Idempotency keys** on `transactions` make a replayed/duplicated request a
  no-op that reports the original result. Purchases combine this with the
  `owned_weapons` UNIQUE constraint so a double-click can't double-charge or
  double-grant.
See [DATABASE.md](DATABASE.md) and [SECURITY.md](SECURITY.md).

## Pay rates (dev defaults)

Per FLRP role, in the `pay_rates` table (cents/hour). Seeded defaults
(migration 008) — **placeholders, subject to change**:

| Role | $/hr (dev) |
|------|-----------|
| Civilian (`member`) | 50 |
| Certified Civ I | 75 |
| Certified Civ II | 100 |
| Certified Civ III | 125 |
| BCSO / FHP / MPD | 150 (only while on that duty) |

Convar fallbacks in `config/economy.cfg` (`flrp_pay_hourly_*`, in **dollars**)
are used only if a role has no `pay_rates` row.

## Pay distribution (active-time intervals)

Hourly pay is paid in smaller chunks so you earn as you play:

```
interval = economy.pay_interval_minutes   (dev default 15)
per-interval pay = hourly_rate / (60 / interval)      -- e.g. hourly/4 every 15 min
```

Every minute the pay loop accrues **active** seconds per player; once a player
has accumulated one interval of active time, they are paid the per-interval
amount for the rate that currently applies, and the accumulator resets. Payouts
are idempotent per pay-cycle bucket.

## Which rate applies (server-authoritative)

1. If the player is **on duty** in BCSO/FHP/MPD (verified by `flrp_duty`, which
   itself verifies they hold the department role), the **department** rate
   applies.
2. Otherwise the **best civilian/certification** rate among the roles they hold
   (`cert_civ_3` > `cert_civ_2` > `cert_civ_1` > `member`).

So a player with the FHP Discord role earns FHP pay only while on FHP duty; if
they go civilian, they earn their certification/civilian pay instead. See
[DEPARTMENTS.md](DEPARTMENTS.md).

## Anti-AFK / active playtime

A player is **active** (compensated) for a tick only when:

- **Server liveness:** `GetPlayerLastMsg(source)` is within
  `economy.afk_timeout_seconds` (default 300s) — a loading/frozen/AFK client
  stops sending network messages; and
- **Client heartbeat:** a lightweight client heartbeat that fires only when the
  player is spawned and has produced recent control input (a truly-AFK player
  stops heartbeating).

The client heartbeat is a **hint** bounded by the server check, so spoofing it
cannot manufacture pay while genuinely idle. There is a short spawn grace after
(re)spawn before accrual begins. `active_playtime_seconds` (compensated) is
tracked separately from `total_playtime_seconds` (raw connected). Configurable
via `economy.pay_requires_active`.

## Starting balance

A brand-new player (no transactions yet) is granted a one-time starting balance
(`economy.starting_balance_cents`, dev default 50000¢ = $500), recorded with an
idempotency key so it is granted exactly once.

## Runtime tuning (FLRP Manager)

Pay rates, pay interval, starting balance, and `pay_requires_active` are all
editable via `flrp_api` (see [WEBSITE_INTEGRATION.md](WEBSITE_INTEGRATION.md))
without code changes. Reload pay rates live with console `flrp_reload_pay`.
