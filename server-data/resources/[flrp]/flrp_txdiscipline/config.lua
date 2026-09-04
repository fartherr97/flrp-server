-- ==========================================================================
-- FLRP :: flrp_txdiscipline/config.lua — txAdmin discipline -> Discord
-- ==========================================================================
-- Listens for txAdmin's player-action events (bans / kicks / warns / revokes)
-- and posts an embed to a Discord channel. The webhook URL is a CREDENTIAL and
-- is read from a convar set in secrets.cfg — never hard-coded here.
--   set flrp_txdiscipline_webhook "https://discord.com/api/webhooks/xxx/yyy"
-- ==========================================================================

FLRP_TXD = {}

FLRP_TXD.WebhookConvar = 'flrp_txdiscipline_webhook'   -- secrets.cfg
FLRP_TXD.PingRoleConvar= 'flrp_txdiscipline_ping_role' -- optional staff role id to ping
FLRP_TXD.Username      = 'FLRP Discipline'
FLRP_TXD.ServerName    = 'Florida Roleplay'
-- Avatar for the webhook message (first non-empty convar wins).
FLRP_TXD.AvatarConvars = { 'flrp_reports_logo', 'flrp_status_logo' }

-- Which events to log.
FLRP_TXD.Log = { ban = true, kick = true, warn = true, revoke = true }

-- Embed colours (0xRRGGBB) + titles.
FLRP_TXD.Ban    = { color = 0xE74C3C, title = '⛔ Player Banned' }
FLRP_TXD.Kick   = { color = 0xE67E22, title = '👢 Player Kicked' }
FLRP_TXD.Warn   = { color = 0xF1C40F, title = '⚠️ Player Warned' }
FLRP_TXD.Revoke = { color = 0x2ECC71, title = '♻️ Action Revoked' }

-- Identifier prefixes worth showing on ban/warn embeds (for offline targets).
FLRP_TXD.ShowIds = { license = true, license2 = true, discord = true, fivem = true, steam = true, live = true }
