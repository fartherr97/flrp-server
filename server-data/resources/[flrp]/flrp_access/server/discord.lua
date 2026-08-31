-- ==========================================================================
-- FLRP :: flrp_access/server/discord.lua — Discord API (server-side only)
-- ==========================================================================
-- Minimal Discord REST client for the membership gate. Only needs the
-- "GET guild member" endpoint, which returns the member's role IDs. Requires
-- the bot to be in the FLRP guild. The token is a private convar and is only
-- ever sent to discord.com in the Authorization header. See docs/SECURITY.md.
-- ==========================================================================

FLRPA = FLRPA or {}
FLRPA.Discord = {}

local API = 'https://discord.com/api/v10'

-- Fetch a guild member. Returns (status, memberTableOrNil).
--   status: 'ok' | 'not_member' | 'unauthorized' | 'rate_limited' | 'error'
-- Blocking (awaits the HTTP promise) — safe to call inside a deferral thread.
function FLRPA.Discord.GetGuildMember(guildId, userId)
  local token = FLRPA.Config.token
  if token == '' or token == 'REPLACE_ME' then
    return 'error', nil
  end

  local p = promise.new()
  local url = ('%s/guilds/%s/members/%s'):format(API, guildId, userId)
  PerformHttpRequest(url, function(statusCode, responseText, headers)
    p:resolve({ code = statusCode, body = responseText, headers = headers })
  end, 'GET', '', {
    ['Authorization'] = 'Bot ' .. token,
    ['Content-Type'] = 'application/json',
    ['User-Agent'] = 'FLRP-Access (flrp-server, 0.1.0)',
  })

  local res = Citizen.Await(p)
  local code = res.code

  if code == 200 then
    local ok, member = pcall(json.decode, res.body)
    if ok and member then return 'ok', member end
    return 'error', nil
  elseif code == 404 then
    return 'not_member', nil
  elseif code == 401 or code == 403 then
    FLRP.Logger.Error('access', 'Discord API auth error (check bot token / guild membership)',
      { code = code })
    return 'unauthorized', nil
  elseif code == 429 then
    FLRP.Logger.Warn('access', 'Discord API rate limited', { code = code })
    return 'rate_limited', nil
  else
    FLRP.Logger.Warn('access', 'Discord API unexpected response', { code = code })
    return 'error', nil
  end
end

-- Does a member table include a given role ID?
function FLRPA.Discord.MemberHasRole(member, roleId)
  if not member or not member.roles then return false end
  for _, r in ipairs(member.roles) do
    if tostring(r) == tostring(roleId) then return true end
  end
  return false
end
