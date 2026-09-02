-- ==========================================================================
-- FLRP :: flrp_chat/config.lua — colors + channel gating
-- ==========================================================================
-- Colors are hex strings matching your Discord role colors. Replace the
-- placeholders below with the real hex codes for each staff tier.
-- ==========================================================================

FLRP_CHAT = {}

-- '#RRGGBB' (or 'RRGGBB') -> { r, g, b }
local function hex(h)
  h = tostring(h):gsub('#', '')
  return {
    tonumber(h:sub(1, 2), 16) or 255,
    tonumber(h:sub(3, 4), 16) or 255,
    tonumber(h:sub(5, 6), 16) or 255,
  }
end

-- Display-name colors for a player's HIGHEST staff tier. Non-staff use default.
-- >>> REPLACE these placeholders with your Discord role hex codes. <<<
FLRP_CHAT.NameColors = {
  ownership = hex('#2ecc71'), -- Ownership
  director  = hex('#3498db'), -- Directorship
  admin     = hex('#9b59b6'), -- Administrator
  staff     = hex('#ff1717'), -- Moderator / staff team
  default   = { 235, 235, 235 }, -- everyone else
}

-- The /sc /ac /dc channels: which ACE may use/see each, its on-screen label,
-- and the tag/name color (defaults to the matching tier color above).
FLRP_CHAT.Channels = {
  sc  = { ace = 'flrp.staff.moderate',   label = 'STAFF CHAT',    color = FLRP_CHAT.NameColors.staff },
  ac  = { ace = 'flrp.staff.administer', label = 'ADMIN CHAT',    color = FLRP_CHAT.NameColors.admin },
  dc  = { ace = 'flrp.staff.direct',     label = 'DIRECTOR CHAT', color = FLRP_CHAT.NameColors.director },
  -- LEO CHAT: all law enforcement, plus staff (mod+) can see/use it too.
  leo = { ace = 'flrp.leo', bypass = 'flrp.staff.moderate', label = 'LEO CHAT', color = hex('#f1c40f') },
}

-- Highest tier first — first ACE the player holds wins their name color.
FLRP_CHAT.Tiers = {
  { ace = 'flrp.staff.own',        key = 'ownership' },
  { ace = 'flrp.staff.direct',     key = 'director' },
  { ace = 'flrp.staff.administer', key = 'admin' },
  { ace = 'flrp.staff.moderate',   key = 'staff' },
}
