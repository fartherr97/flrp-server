-- ==========================================================================
-- FLRP :: flrp_access/server/namecheck.lua — in-game name must match Discord
-- ==========================================================================
-- Members of the ENFORCED groups (Cert Civ, Staff = Mod/Admin, LEO = BSO/FHP/
-- MPD) must connect with an in-game name that matches their Discord guild
-- display name (server nickname, else global name, else username). Director
-- and Ownership are EXEMPT. On a mismatch the connection is denied at the gate
-- with a fix-your-name message. Toggle with the flrp_name_enforce convar.
--
-- Match rule: EXACT — case-insensitive, whitespace collapsed, FiveM colour
-- codes stripped. (So "1A-12 | Dep | Mike" must equal the Discord display name
-- verbatim apart from case/spacing.)
-- ==========================================================================

FLRPA = FLRPA or {}
FLRPA.NameCheck = {}

-- Groups whose members must match; Director/Ownership override (exempt).
local ENFORCE_KEYS = {
  cert_civ_1 = true, cert_civ_2 = true, cert_civ_3 = true,
  moderator = true, administrator = true,
  bso = true, fhp = true, mpd = true,
}
local EXEMPT_KEYS = { director = true, ownership = true }

-- Normalize for an exact compare: strip FiveM colour codes (^1 etc.), collapse
-- whitespace, trim, lowercase.
local function norm(s)
  s = tostring(s or ''):gsub('%^%d', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  return s:lower()
end

-- Discord guild display name: nickname > global display name > username.
local function displayNameOf(member)
  if not member then return nil end
  if member.nick and member.nick ~= '' then return member.nick end
  local u = member.user
  if u then
    if u.global_name and u.global_name ~= '' then return u.global_name end
    if u.username and u.username ~= '' then return u.username end
  end
  return nil
end

-- Evaluate a connecting player. Returns:
--   ok(true)                         -> allow
--   ok(false), discordName, keys     -> deny (name mismatch, must fix)
-- Never denies when it lacks the data to be sure (missing display name, no
-- enforced role, etc.) — fail-open on ambiguity so nobody is wrongly kicked.
function FLRPA.NameCheck.Evaluate(gameName, member)
  if not FLRPA.Config.nameEnforce then return true end
  if not member then return true end

  local keys = {}
  pcall(function() keys = exports.flrp_permissions:ResolveDiscordRoles(member.roles or {}) or {} end)

  for k in pairs(EXEMPT_KEYS) do if keys[k] then return true end end   -- Director/Owner exempt

  local enforced = false
  for k in pairs(ENFORCE_KEYS) do if keys[k] then enforced = true break end end
  if not enforced then return true end

  local discordName = displayNameOf(member)
  if not discordName or discordName == '' then return true end        -- can't compare -> don't punish

  if norm(gameName) == norm(discordName) then return true end
  return false, discordName
end
