# FLRP Security

**Treat every FiveM client as malicious and untrusted.** Nothing the client
sends about money, prices, weapons, permissions, department, duty, certification,
vehicle eligibility, or Discord identity is trusted. All of it is validated
server-side.

## Never trust the client for

| Concern | How FLRP handles it |
|--------|---------------------|
| Money / balance | Server-only. `flrp_economy` computes all pay + deducts via guarded atomic UPDATE. Client never sends amounts that are believed. |
| Prices | Server fetches the **authoritative** price from the `weapons` registry at purchase time; the client's displayed price is ignored. |
| Weapons | Purchase requires server-side registry/eligibility/permission checks; ownership is server-recorded. |
| Permissions | `flrp_permissions` resolves from DB roles server-side; client cannot escalate. |
| Department / duty | `flrp_duty` verifies the player holds the department role before honoring a duty change. |
| Certification | Resolved from server-side roles, not client claims. |
| Vehicle eligibility | `flrp_vehicles:CanSpawn` decides server-side. |
| Discord identity | Server-derived identifiers only; roles read by the server via the bot, passed over a server event (never a net event). |

## Threats & mitigations

- **Arbitrary client events / arbitrary resource invocation** — server event
  handlers validate `source` and re-check permissions; role data flows over
  server-side events (`AddEventHandler`), never client-triggerable
  `RegisterNetEvent`, for `flrp_access:discordRolesResolved`.
- **Money manipulation** — integer cents, guarded atomic debits, append-only
  ledger with `balance_after_cents`, non-negative CHECK.
- **Weapon-spawn exploits** — `weapon.vmenu.spawn` is authoritative (DB +
  ACE); vMenu itself is denied weapon spawning for unauthorized groups.
- **Permission escalation** — one central engine; no ad-hoc role checks; ACE
  principals are attached per-connection and removed on drop.
- **Discord spoofing** — identity + roles are server-derived; bot token never
  leaves the server.
- **SQL injection** — all queries parameterized (oxmysql placeholders); no
  concatenation of user input.
- **IDOR** — callers pass `source`; the server resolves to `players.id` itself,
  so a client cannot reference another player's DB id.
- **Race conditions** — guarded atomic UPDATE + row locks; in-flight lock on
  purchases. See [DATABASE.md](DATABASE.md).
- **Replay / duplicate requests** — UNIQUE `idempotency_key` on transactions;
  UNIQUE `(player_id, weapon_id)` on ownership; per-source purchase lock.
- **API abuse** — `flrp_api` requires a shared secret (constant-time compare,
  fail-closed when unset); every write is audited; audit log is read-only via
  the API.

## Secrets handling

- Real secrets live **only** in `server-data/config/secrets.cfg`, which is
  **gitignored**. Only `secrets.example.cfg` (placeholders) is tracked.
- Discord bot token, DB connection string, and API secret are **private
  convars** read server-side with `GetConvar`; they are never sent to clients
  and never logged.
- Rotate secrets by editing `secrets.cfg` and reloading (`flrp_reload_access`,
  restart, etc.). Keep backups of `secrets.cfg` outside the repo.

## Known limits (documented, not silently ignored)

- **External mod menus** can still spawn weapons/vehicles locally in any FiveM
  server; FiveM cannot fully prevent this client-side. FLRP enforces the
  **policy** (ownership/authorization for anything obtained through FLRP) and
  server-authoritative economy/permissions. Pair with a dedicated anti-cheat
  (e.g. server-side entity/weapon monitoring) for cheat detection — out of scope
  for this foundation.
- The debit → ledger write is race-safe for the balance invariant; a crash in
  the microsecond window between the guarded UPDATE and the ledger INSERT would
  leave money correct but a ledger row missing. This is an accepted, minimal
  trade-off for portability; it can be tightened with a stored routine if
  stricter ledger atomicity is ever required.

## Reporting

Handle suspected vulnerabilities privately with server leadership; do not post
exploit details publicly.
