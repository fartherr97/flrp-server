-- ==========================================================================
-- FLRP :: flrp_status/config.lua — live server-status embed
-- ==========================================================================
-- The embed is posted once to a webhook, then EDITED every UpdateSeconds so it
-- stays a single live message (no bot token needed). Set these convars in
-- secrets.cfg (webhook is credential-like) / server.cfg:
--   set flrp_status_webhook  "https://discord.com/api/webhooks/xxx/yyy"
--   set flrp_status_join_url "https://cfx.re/join/xxxxxx"   (the FiveM join link)
-- ==========================================================================

FLRP_STATUS = {}

FLRP_STATUS.WebhookConvar  = 'flrp_status_webhook'
FLRP_STATUS.JoinUrlConvar  = 'flrp_status_join_url'

FLRP_STATUS.UpdateSeconds  = 45          -- how often the embed refreshes
FLRP_STATUS.ServerName     = 'Florida Roleplay'
FLRP_STATUS.Username       = 'FLRP Status'
FLRP_STATUS.JoinLabel      = 'Click Here'
FLRP_STATUS.Color          = 0x2ecc71     -- online = green
FLRP_STATUS.Thumbnail      = 'https://www.flrp.us/images/0cf4f7264d435b3b.png' -- logo

-- Which ACE marks a "staff" member (for Staff In-Game count + roster).
FLRP_STATUS.StaffAce       = 'flrp.staff.moderate'

-- nex-duty entity ids that count as LEO (from flrp_duty's entity map), in the
-- order they should appear, each with the label shown in the embed.
FLRP_STATUS.LeoDepts = {
  { id = 'bso', label = 'BSO' },
  { id = 'fhp', label = 'FHP' },
  { id = 'mpd', label = 'MPD' },
}
-- Fire/EMS entity ids (none yet — fill when a fire dept is added to nex-duty).
FLRP_STATUS.FireDepts = {}

-- nex-hud area codes -> friendly names, used for both the AOP list and the
-- priority zones. Any code not listed here is shown upper-cased as-is, so add
-- or correct entries as you learn what each code means.
FLRP_STATUS.AreaNames = {
  ss    = 'Sandy Shores',
  pb    = 'Paleto Bay',
  ls    = 'Los Santos',
  bc    = 'Blaine County',
  fz    = 'Fort Zancudo',
  banks = 'Banham / Banks',
  gs    = 'Grapeseed',
  ch    = 'Chumash',
}

-- Set true to print the raw shapes of getAop/getPriority/getUnitsByEntities to
-- the server console once at boot (and once more the first time a unit is on
-- duty, so the unit fields can be mapped). Flip to false when done.
FLRP_STATUS.Debug = true
