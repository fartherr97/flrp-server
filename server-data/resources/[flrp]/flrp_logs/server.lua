-- ==========================================================================
-- FLRP :: flrp_logs/server.lua — Discord webhook sender (SSRP-style embeds)
-- ==========================================================================
-- Public API:
--   exports.flrp_logs:Send(category, {
--     player      = src,        -- optional; adds the "[id] pid | rank | name" line
--     title       = 'STRING',   -- overrides the category default
--     description = 'STRING',   -- the body
--     color       = 0xRRGGBB,   -- overrides the category color
--     fields      = { {name=, value=, inline=} },  -- optional extra fields
--     content     = 'STRING',   -- optional plain text ABOVE the embed (where role
--                               --   pings go, e.g. '<@&ROLEID> **Name** did X')
--     mentionRoles= { 'ROLEID' } -- role ids allowed to actually ping (Discord
--                               --   needs allowed_mentions or the ping is inert)
--   })
-- Categories + webhook convars live in config.lua. A category with no webhook
-- configured is skipped silently.
-- ==========================================================================

local function webhookFor(category)
  local c = FLRP_LOGS.Categories[category]
  if not c then return nil end
  local url = GetConvar(c.convar, '')
  if url == '' or not url:find('discord') then return nil end
  return url, c
end

local function rankOf(src)
  for _, r in ipairs(FLRP_LOGS.Ranks) do
    if IsPlayerAceAllowed(src, r.ace) then return r.label end
  end
  return 'Civilian'
end

-- "[<serverId>] <flrpId> | <rank> | <name>" — flrpId omitted if unavailable.
local function playerLine(src)
  local name = GetPlayerName(src) or ('Player ' .. tostring(src))
  local rank = rankOf(src)
  local flrpId
  local ok, rec = pcall(function() return exports.flrp_core:GetPlayer(src) end)
  if ok and type(rec) == 'table' then flrpId = rec.playerId or rec.id end
  if flrpId then
    return ('`[%s] %s | %s | %s`'):format(src, flrpId, rank, name)
  end
  return ('`[%s] %s | %s`'):format(src, rank, name)
end

local function Send(category, opts)
  local url, cat = webhookFor(category)
  if not url then return end
  opts = opts or {}

  local fields = {}
  if opts.player then
    fields[#fields + 1] = { name = 'Player', value = playerLine(opts.player), inline = false }
  end
  if opts.fields then
    for _, f in ipairs(opts.fields) do fields[#fields + 1] = f end
  end

  local embed = {
    title       = opts.title or cat.title,
    description = opts.description,
    color       = opts.color or cat.color,
    fields      = (#fields > 0) and fields or nil,
    timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
  }

  PerformHttpRequest(url, function(status, body)
    if status ~= 200 and status ~= 204 then
      print(('^1[flrp_logs] "%s" webhook failed: HTTP %s %s^0'):format(
        category, tostring(status), tostring(body)))
    end
  end, 'POST', json.encode({
    username         = FLRP_LOGS.Username,
    avatar_url       = (FLRP_LOGS.Avatar ~= '' and FLRP_LOGS.Avatar) or nil,
    content          = (opts.content and opts.content ~= '') and opts.content or nil,
    embeds           = { embed },
    -- Only roles listed here will actually ping; everything else stays inert.
    allowed_mentions = (type(opts.mentionRoles) == 'table' and #opts.mentionRoles > 0)
                         and { parse = {}, roles = opts.mentionRoles } or nil,
  }), { ['Content-Type'] = 'application/json' })
end

exports('Send', Send)

-- On boot, print which categories actually have a webhook configured, so a
-- missing/typo'd convar is obvious in the console.
CreateThread(function()
  Wait(1500)
  local on = {}
  for cat in pairs(FLRP_LOGS.Categories) do
    if webhookFor(cat) then on[#on + 1] = cat end
  end
  table.sort(on)
  print(('[flrp_logs] webhooks configured: %s'):format(#on > 0 and table.concat(on, ', ') or 'NONE'))
end)

-- ---- Built-in wiring: joins / leaves ------------------------------------
-- Name goes in the description; no Player field (the FiveM name already carries
-- the full ID | rank | name, so the field was redundant here).
AddEventHandler('playerJoining', function()
  local name = GetPlayerName(source) or ('Player ' .. source)
  Send('join', { description = ('**%s** connected.'):format(name) })
end)

AddEventHandler('playerDropped', function(reason)
  local name = GetPlayerName(source) or ('Player ' .. source)
  Send('leave', { description = reason and ('**%s** disconnected — %s'):format(name, reason)
                                        or ('**%s** disconnected.'):format(name) })
end)

RegisterNetEvent('flrp_logs:death', function(kind)
  local name = GetPlayerName(source) or ('Player ' .. source)
  Send('death', { description = ('**%s** %s.'):format(name, kind == 'killed' and 'was killed' or 'died') })
end)
