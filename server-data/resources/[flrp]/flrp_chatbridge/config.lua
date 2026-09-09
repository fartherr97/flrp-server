-- ==========================================================================
-- FLRP :: flrp_chatbridge/config.lua
-- ==========================================================================
FLRP_CHATBRIDGE = {}

-- Discord webhook for the #ingame-chat channel. Set in secrets.cfg:
--   set flrp_chat_bridge_webhook "https://discord.com/api/webhooks/..."
FLRP_CHATBRIDGE.WebhookConvar = 'flrp_chat_bridge_webhook'
FLRP_CHATBRIDGE.Username      = 'FLRP Chat'   -- webhook display name
FLRP_CHATBRIDGE.Avatar        = ''            -- optional avatar URL

-- Batching: lines are queued and sent together so a busy chat never trips the
-- webhook rate limit. A batch goes out this many ms after its first line, or
-- sooner once it nears Discord's 2000-character message limit.
FLRP_CHATBRIDGE.FlushMs   = 2500
FLRP_CHATBRIDGE.MaxChars  = 1900

-- Which tags reach Discord. `chat` = normal T-chat, `gooc` = /gooc, `gme` = /gme.
-- Local /ooc and /me never leave the game.
FLRP_CHATBRIDGE.Relay = { chat = true, gooc = true, gme = true }

-- How each tag is rendered in Discord. {id} = server id, {name} = player name,
-- {msg} = message. Bold the sender like SSRP's "[12] GOOC | Name: msg" style.
FLRP_CHATBRIDGE.Format = {
  chat = '**[{id}] {name}**: {msg}',
  gooc = '**[{id}] GOOC | {name}**: {msg}',
  gme  = '**[{id}] {name}** *{msg}*',
}

-- Inbound (Discord -> game) rendering.
FLRP_CHATBRIDGE.InboundPrefix = '[Discord]'
FLRP_CHATBRIDGE.InboundColor  = { 88, 101, 242 }   -- Discord blurple
FLRP_CHATBRIDGE.InboundMaxLen = 256
