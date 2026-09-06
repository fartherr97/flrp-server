-- ==========================================================================
-- FLRP :: flrp_chatfilter/config.lua — zero-tolerance slur filter
-- ==========================================================================
-- Severe slurs (racial / homophobic) are BLOCKED from chat and the sender is
-- auto-kicked; a Discord embed is posted (flrp_logs category `chatfilter`)
-- pinging the staff role. Ordinary profanity (shit, fuck, …) is intentionally
-- NOT filtered — it passes through untouched.
--
-- Matching is obfuscation-resistant: it ignores case, spacing and punctuation
-- between letters, and common leetspeak (n1gg3r, f@ggot, n i g g e r all hit),
-- while word-boundary anchoring keeps innocent words safe (Nigeria, bigger,
-- trigger, snigger, class, etc. do NOT trip it).
-- ==========================================================================

FLRP_CHATFILTER = {}

FLRP_CHATFILTER.Enabled     = true
FLRP_CHATFILTER.KickPlayer  = true
FLRP_CHATFILTER.LogCategory = 'chatfilter'   -- flrp_logs webhook (set flrp_log_webhook_chatfilter in secrets.cfg)
FLRP_CHATFILTER.KickMessage = '[FLRP] Kicked: use of a prohibited slur. Appeal in our Discord.'

-- Discord role id pinged ABOVE the embed. Role ids are NOT secrets, so this
-- lives in git; you can also override it with the `flrp_staff_role_id` convar.
FLRP_CHATFILTER.StaffRoleId = ''             -- e.g. '123456789012345678' (Community Staff Team)

-- Severe slurs -> delete + kick + ping. Lowercase roots only; the matcher adds
-- the obfuscation handling. Edit this list to taste (Ownership decision).
FLRP_CHATFILTER.Banned = {
  'nigger',   -- hard-R
  'faggot',
  'chink',
  'kike',
  'spic',
  'gook',
  'wetback',
  'tranny',
}

-- Extra roots you may want but that are more debatable — off by default.
-- Copy any into Banned above to enable. (e.g. 'nigga', 'fag', 'retard')
FLRP_CHATFILTER.Optional = { 'nigga', 'fag', 'coon', 'beaner', 'retard' }
