-- ==========================================================================
-- FLRP :: flrp_core/server/identity.lua — FiveM identity extraction
-- ==========================================================================
-- Extracts a player's identifiers (license, discord, steam, ...) from the
-- FiveM runtime. Identity is SERVER-DERIVED ONLY — never trust a client to
-- report its own license/discord. See docs/SECURITY.md.
--
-- `license` (rockstar license) is our primary stable identity. `discord` is
-- required for the connection gate (flrp_access). Values are returned WITHOUT
-- the "type:" prefix.
-- ==========================================================================

FLRP = FLRP or {}
FLRP.Identity = {}

-- Parse all identifiers for a connected source into a { type = value } map.
-- Also returns an ordered array of { type, value } for full persistence.
function FLRP.Identity.GetIdentifiers(source)
  local map, list = {}, {}
  local count = GetNumPlayerIdentifiers(source) or 0
  for i = 0, count - 1 do
    local ident = GetPlayerIdentifier(source, i) -- e.g. "license:abc", "discord:123"
    if ident then
      local itype, ivalue = ident:match('^(%w+):(.+)$')
      if itype and ivalue then
        map[itype] = map[itype] or ivalue      -- keep first of each type
        list[#list + 1] = { type = itype, value = ivalue }
      end
    end
  end
  return map, list
end

-- Convenience: license (no prefix) or nil.
function FLRP.Identity.GetLicense(source)
  local map = FLRP.Identity.GetIdentifiers(source)
  return map.license
end

-- Convenience: discord id (numeric string, no prefix) or nil.
function FLRP.Identity.GetDiscordId(source)
  local map = FLRP.Identity.GetIdentifiers(source)
  return map.discord
end

-- During the deferral (playerConnecting), identifiers are available via the
-- `deferrals`/`playerConnecting` source too. This helper reads them from the
-- transient connecting source id used by flrp_access.
function FLRP.Identity.GetConnectingDiscordId(source)
  return FLRP.Identity.GetDiscordId(source)
end
