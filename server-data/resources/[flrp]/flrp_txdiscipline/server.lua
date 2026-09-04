-- ==========================================================================
-- FLRP :: flrp_txdiscipline/server.lua — txAdmin discipline -> Discord webhook
-- ==========================================================================
-- txAdmin (the `monitor` resource) broadcasts these server events; we format an
-- embed and POST it to the discipline webhook. Field names follow txAdmin's
-- documented event payloads (docs/events.md).
-- ==========================================================================

local function webhook()
  local url = GetConvar(FLRP_TXD.WebhookConvar, '')
  if url == '' or not url:find('discord') then return nil end
  return url
end

local function avatar()
  for _, cv in ipairs(FLRP_TXD.AvatarConvars) do
    local v = GetConvar(cv, ''); if v ~= '' then return v end
  end
  return nil
end

-- One embed field, with an em-dash for empty values.
local function field(name, value, inline)
  local v = value
  if v == nil or v == '' then v = '—' end
  return { name = name, value = tostring(v), inline = inline or false }
end

-- Pull the interesting identifiers out of a txAdmin ids array.
local function idBlock(ids)
  if type(ids) ~= 'table' then return '—' end
  local out = {}
  for _, id in ipairs(ids) do
    local key = tostring(id):match('^(%w+):')
    if key and FLRP_TXD.ShowIds[key] then out[#out + 1] = '`' .. tostring(id) .. '`' end
  end
  return #out > 0 and table.concat(out, '\n') or '—'
end

local function post(spec, fields)
  local url = webhook(); if not url then return end
  local embed = {
    title     = spec.title,
    color     = spec.color,
    fields    = fields,
    footer    = { text = FLRP_TXD.ServerName .. ' • txAdmin' },
    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
  }
  local payload = { username = FLRP_TXD.Username, embeds = { embed } }
  local av = avatar(); if av then payload.avatar_url = av end

  local role = GetConvar(FLRP_TXD.PingRoleConvar, '')
  if role ~= '' and role ~= 'REPLACE_ME' then
    payload.content = ('<@&%s>'):format(role)
    payload.allowed_mentions = { parse = {}, roles = { role } }
  end

  PerformHttpRequest(url, function(status, _body)
    if status ~= 200 and status ~= 204 then
      print(('[flrp_txdiscipline] webhook POST failed: HTTP %s'):format(tostring(status)))
    end
  end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- ---- ban ------------------------------------------------------------------
AddEventHandler('txAdmin:events:playerBanned', function(d)
  if not FLRP_TXD.Log.ban or type(d) ~= 'table' then return end
  local dur = (d.expiration == false) and 'Permanent'
              or (d.durationTranslated or d.durationInput or 'Temporary')
  post(FLRP_TXD.Ban, {
    field('Player',      d.targetName, true),
    field('Admin',       d.author,     true),
    field('Duration',    dur,          true),
    field('Reason',      d.reason,     false),
    field('Identifiers', idBlock(d.targetIds), false),
    field('Ban ID',      d.actionId,   true),
  })
end)

-- ---- kick -----------------------------------------------------------------
AddEventHandler('txAdmin:events:playerKicked', function(d)
  if not FLRP_TXD.Log.kick or type(d) ~= 'table' then return end
  local who
  if tonumber(d.target) == -1 then
    who = 'Everyone'
  else
    local name = GetPlayerName(d.target)
    who = (name and (name .. ' (id ' .. tostring(d.target) .. ')')) or ('Player ' .. tostring(d.target))
  end
  post(FLRP_TXD.Kick, {
    field('Player', who,      true),
    field('Admin',  d.author, true),
    field('Reason', d.reason, false),
  })
end)

-- ---- warn -----------------------------------------------------------------
AddEventHandler('txAdmin:events:playerWarned', function(d)
  if not FLRP_TXD.Log.warn or type(d) ~= 'table' then return end
  post(FLRP_TXD.Warn, {
    field('Player',      d.targetName, true),
    field('Admin',       d.author,     true),
    field('Warn ID',     d.actionId,   true),
    field('Reason',      d.reason,     false),
    field('Identifiers', idBlock(d.targetIds), false),
  })
end)

-- ---- action revoked (unban / unwarn) --------------------------------------
AddEventHandler('txAdmin:events:actionRevoked', function(d)
  if not FLRP_TXD.Log.revoke or type(d) ~= 'table' then return end
  local player = (d.playerName == false or d.playerName == nil) and 'Unknown' or d.playerName
  post(FLRP_TXD.Revoke, {
    field('Type',           d.actionType,   true),
    field('Revoked By',     d.revokedBy,    true),
    field('Player',         player,         true),
    field('Original Admin', d.actionAuthor, true),
    field('Action ID',      d.actionId,     true),
    field('Original Reason',d.actionReason, false),
  })
end)

CreateThread(function()
  Wait(2000)
  if webhook() then
    print('[flrp_txdiscipline] listening for txAdmin discipline events.')
  else
    print('[flrp_txdiscipline] flrp_txdiscipline_webhook not set — discipline logging disabled.')
  end
end)
