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

  PerformHttpRequest(url, function() end, 'POST', json.encode({
    username   = FLRP_LOGS.Username,
    avatar_url = (FLRP_LOGS.Avatar ~= '' and FLRP_LOGS.Avatar) or nil,
    embeds     = { embed },
  }), { ['Content-Type'] = 'application/json' })
end

exports('Send', Send)

-- ---- Built-in wiring: joins / leaves ------------------------------------
-- Descriptions deliberately omit the name — it already appears in the Player
-- field below, so repeating it here just duplicated it in the embed.
AddEventHandler('playerJoining', function()
  Send('join', { player = source, description = 'Connected.' })
end)

AddEventHandler('playerDropped', function(reason)
  local src = source
  Send('leave', { player = src, description = reason and ('Disconnected — %s'):format(reason) or 'Disconnected.' })
end)

RegisterNetEvent('flrp_logs:death', function(kind)
  Send('death', { player = source, description = (kind == 'killed') and 'Was killed.' or 'Died.' })
end)
