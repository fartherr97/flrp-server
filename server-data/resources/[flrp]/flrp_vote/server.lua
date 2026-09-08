-- ==========================================================================
-- FLRP :: flrp_vote/server.lua — one active vote, authoritative tally
-- ==========================================================================

local CFG = FLRP_VOTE
local function isStaff(src) return IsPlayerAceAllowed(src, CFG.StartAce) end
local function pname(src)   return GetPlayerName(src) or ('Player ' .. src) end
local function trim(s)      return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function toast(src, kind, body)
  TriggerClientEvent('flrp_notify:toast', src, { title = 'Vote', kind = kind, body = body })
end

local active = nil    -- { id, title, options={}, votes={[src]=idx}, starter }
local seq = 0

local function finish(id)
  if not active or active.id ~= id then return end
  local counts = {}
  for i = 1, #active.options do counts[i] = 0 end
  for _, idx in pairs(active.votes) do if counts[idx] then counts[idx] = counts[idx] + 1 end end
  local total, winIdx, winCount = 0, 0, -1
  for i, c in ipairs(counts) do
    total = total + c
    if c > winCount then winIdx, winCount = i, c end
  end
  TriggerClientEvent('flrp_vote:results', -1, {
    title = active.title, options = active.options, counts = counts, total = total,
    winner = (total > 0) and winIdx or 0, seconds = CFG.ResultSeconds,
  })
  print(('[flrp_vote] "%s" ended — winner: %s (%d/%d)'):format(
    active.title, active.options[winIdx] or '—', winCount >= 0 and winCount or 0, total))
  active = nil
end

-- /startvote (staff) -> server confirms staff, then opens the builder client-side.
RegisterNetEvent('flrp_vote:open', function()
  local src = source
  if not isStaff(src) then return end
  if active then return toast(src, 'error', 'A vote is already running.') end
  TriggerClientEvent('flrp_vote:openConfig', src, {
    maxOptions = CFG.MaxOptions, minSeconds = CFG.MinSeconds,
    maxSeconds = CFG.MaxSeconds, defaultSeconds = CFG.DefaultSeconds })
end)

-- Staff submitted a built vote -> broadcast the ballot to everyone.
RegisterNetEvent('flrp_vote:start', function(data)
  local src = source
  if not isStaff(src) then return end
  if active then return toast(src, 'error', 'A vote is already running.') end
  data = data or {}

  local title = trim(data.title):sub(1, 120)
  local secs = math.max(CFG.MinSeconds, math.min(CFG.MaxSeconds, math.floor(tonumber(data.seconds) or CFG.DefaultSeconds)))
  local opts = {}
  for _, o in ipairs(data.options or {}) do
    o = trim(o):sub(1, 80)
    if o ~= '' then opts[#opts + 1] = o end
    if #opts >= CFG.MaxOptions then break end
  end
  if title == '' or #opts < 2 then
    return toast(src, 'error', 'Need a question and at least 2 options.')
  end

  seq = seq + 1
  active = { id = seq, title = title, options = opts, votes = {}, starter = src }
  local id = seq

  TriggerClientEvent('flrp_vote:ballot', -1, { title = title, options = opts, seconds = secs })
  print(('[flrp_vote] %s started "%s" (%ds, %d options)'):format(pname(src), title, secs, #opts))
  SetTimeout(secs * 1000, function() finish(id) end)
end)

RegisterNetEvent('flrp_vote:cast', function(index)
  local src = source
  if not active then return end
  index = tonumber(index)
  if not index or not active.options[index] then return end
  active.votes[src] = index
end)

RegisterCommand(CFG.CancelCommand or 'cancelvote', function(src)
  if type(src) ~= 'number' or src <= 0 then return end
  if not isStaff(src) or not active then return end
  active = nil
  TriggerClientEvent('flrp_vote:cancel', -1)
  print('[flrp_vote] vote cancelled by ' .. pname(src))
end, false)

AddEventHandler('playerDropped', function()
  if active then active.votes[source] = nil end
end)
