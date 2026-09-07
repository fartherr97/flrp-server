-- ==========================================================================
-- FLRP :: flrp_access/server/namecheck.lua — in-game name must match Discord
-- ==========================================================================
-- Members of the ENFORCED groups (Cert Civ, Staff = Mod/Admin, LEO = BSO/FHP/
-- MPD) must connect with an in-game name that matches their Discord guild
-- display name (server nickname, else global name, else username). Director
-- and Ownership are EXEMPT. On a mismatch the connection is denied at the gate
-- with a fix-your-name message. Toggle with the flrp_name_enforce convar.
--
-- Match rule: EXACT and CASE-SENSITIVE. FiveM colour codes are stripped and
-- runs of whitespace are collapsed/trimmed, but case must match exactly — so
-- "123 | mod | jones" is REJECTED against "123 | Mod | Jones".
-- ==========================================================================

FLRPA = FLRPA or {}
FLRPA.NameCheck = {}

-- Enforce by role KIND, not an exhaustive key list — so every certification
-- tier (Cert Civ I/II/III, Supervisor, …), every department, and every staff
-- rank is covered automatically as it's added, with no code change. `base`
-- (plain community member) is never enforced.
local ENFORCE_KINDS = { certification = true, department = true, staff = true }
-- Staff-kind roles that are nonetheless EXEMPT (checked by key).
local EXEMPT_KEYS = { director = true, ownership = true }

-- Normalize for an exact, CASE-SENSITIVE compare: strip FiveM colour codes
-- (^1 etc.), collapse whitespace runs, trim. Case is preserved on purpose.
local function norm(s)
  return (tostring(s or ''):gsub('%^%d', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', ''))
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

  local kinds = {}   -- { [roleKey] = kind }
  pcall(function() kinds = exports.flrp_permissions:ResolveDiscordRoleKinds(member.roles or {}) or {} end)

  for key in pairs(kinds) do if EXEMPT_KEYS[key] then return true end end   -- Director/Owner exempt

  local enforced = false
  for _, kind in pairs(kinds) do if ENFORCE_KINDS[kind] then enforced = true break end end
  if not enforced then return true end

  local discordName = displayNameOf(member)
  if not discordName or discordName == '' then return true end        -- can't compare -> don't punish

  if norm(gameName) == norm(discordName) then return true end
  return false, discordName
end
