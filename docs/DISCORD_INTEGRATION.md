# FLRP Discord Integration

Players **must** be verified members of the FLRP Discord to join FiveM. The gate
is enforced server-side in `flrp_access` using `playerConnecting` deferrals.

## Flow

```
connect
  → identify FiveM player (server-derived identifiers)
  → obtain Discord ID (from FiveM↔Discord link)
  → GET guild member from Discord API (bot token)
  → verify guild membership          (404 => not a member => DENY)
  → verify Community Member role      (missing => DENY)
  → read the member's Discord roles
  → hand roles to flrp_permissions (server event)
  → ALLOW connection
```

If any step fails, the deferral is **denied** with a helpful message + the
invite URL.

## Required setup

### Bot

1. Create a Discord application + bot; invite it to the FLRP guild.
2. Enable **Server Members Intent** (Developer Portal → Bot → Privileged Gateway
   Intents). Required to read member roles.
3. The bot needs only to be a guild member; no special permissions beyond
   viewing members.

### Secrets (`config/secrets.cfg`)

```
set flrp_discord_token "<bot token>"          # server-side only, NEVER committed
set flrp_discord_guild_id "<guild/server id>"
set flrp_discord_invite_url "https://discord.gg/<invite>"
set flrp_role_community_member "<role id>"    # required verification role
```

### Role IDs (placeholders — fill with REAL IDs; do not invent)

Set each in `secrets.cfg`. These bootstrap the Discord→FLRP role mapping without
any DB rows:

```
set flrp_role_ownership     "<id>"
set flrp_role_director      "<id>"
set flrp_role_administrator "<id>"
set flrp_role_moderator     "<id>"
set flrp_role_cert_civ_1    "<id>"
set flrp_role_cert_civ_2    "<id>"
set flrp_role_cert_civ_3    "<id>"
set flrp_role_bcso          "<id>"
set flrp_role_fhp           "<id>"
set flrp_role_mpd           "<id>"
```

To get a role ID: Discord → Server Settings → Roles → right-click a role → Copy
ID (Developer Mode on). To get the guild ID: right-click the server icon → Copy
Server ID.

You can also (or instead) manage mappings in the DB `discord_role_mappings`
table via the FLRP Manager. DB mappings and convar mappings are merged.

## Players: linking Discord to FiveM

A player's Discord ID is only visible to the server if they have linked FiveM to
Discord (Discord → Settings → Connections → link the FiveM/Rockstar connection,
or run FiveM with Discord running). If no `discord:` identifier is present, the
gate denies with instructions to link.

## Failure policy

`flrp_access` supports two convars:

- `flrp_access_enabled` (default `true`) — set `false` on a dev box to bypass
  the gate entirely (players get base `member` only). **Never in production.**
- `flrp_access_fail_open` (default `false`) — if the Discord API is
  unreachable/misconfigured, `true` lets players in with base `member` only,
  `false` denies. Default **fail-closed** (deny) for security.

## Security

- The bot token is a **private convar**, read only server-side, sent only to
  `discord.com` in the `Authorization` header. It is never sent to clients and
  never committed. See [SECURITY.md](SECURITY.md).
- Discord identity is **server-derived** — a client cannot spoof its Discord ID
  or roles. Roles flow `flrp_access → flrp_permissions` over a server event, not
  a client-triggerable net event.
- Rate limits (HTTP 429) are handled by denying with a "try again" message
  rather than failing open.
