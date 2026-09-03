-- ==========================================================================
-- FLRP :: flrp_leotools/server.lua — authoritative LEO restraint state
-- ==========================================================================
-- Every action is initiated by an officer client, re-validated here (ACE +
-- proximity), and applied by telling the TARGET's client what to do. The
-- server owns the canonical cuffed/dragged state so drag/seat can require an
-- actual cuff first and so nothing can be forged by a target.
-- ==========================================================================

local cuffed  = {}  -- [targetSrc] = true
local dragged = {}  -- [targetSrc] = officerSrc

local function isLeo(src) return IsPlayerAceAllowed(src, FLRP_LEO.Ace) end

-- Server-side distance between two players (OneSync gives us coords).
local function within(a, b, max)
  local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
  if pa == 0 or pb == 0 then return false end
  local ca, cb = GetEntityCoords(pa), GetEntityCoords(pb)
  return #(ca - cb) <= max
end

local function name(src) return GetPlayerName(src) or ('Player ' .. src) end

local function log(officer, target, what)
  pcall(function()
    exports.flrp_logs:Send('jail', {
      player = officer, title = 'LEO ' .. what:upper(),
      description = ('%s %s %s'):format(name(officer), what, name(target)),
    })
  end)
end

-- ---- cuff toggle ---------------------------------------------------------
RegisterNetEvent('flrp_leotools:cuff', function(target)
  local src = source
  target = tonumber(target)
  if not isLeo(src) or not target or not GetPlayerName(target) then return end
  if not within(src, target, FLRP_LEO.Reach) then
    return TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'error', body = 'Nobody in reach to cuff.' })
  end
  local on = not cuffed[target]
  cuffed[target] = on or nil
  if not on then                    -- uncuffing also drops any drag
    if dragged[target] then dragged[target] = nil; TriggerClientEvent('flrp_leotools:drag', target, nil, false) end
  end
  TriggerClientEvent('flrp_leotools:cuff', target, src, on)
  TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'ok', body = (on and 'Cuffed ' or 'Uncuffed ') .. name(target) })
  log(src, target, on and 'cuffed' or 'uncuffed')
end)

-- ---- drag / escort toggle ------------------------------------------------
RegisterNetEvent('flrp_leotools:drag', function(target)
  local src = source
  target = tonumber(target)
  if not isLeo(src) or not target or not GetPlayerName(target) then return end
  -- Toggling drag: if this officer is already dragging the target, release.
  if dragged[target] == src then
    dragged[target] = nil
    TriggerClientEvent('flrp_leotools:drag', target, nil, false)
    TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'ok', body = 'Released ' .. name(target) })
    return
  end
  if not cuffed[target] then
    return TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'error', body = 'They must be cuffed first.' })
  end
  if not within(src, target, FLRP_LEO.Reach) then
    return TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'error', body = 'Nobody in reach to escort.' })
  end
  dragged[target] = src
  TriggerClientEvent('flrp_leotools:drag', target, src, true)
  TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'ok', body = 'Escorting ' .. name(target) })
  log(src, target, 'escorted')
end)

-- ---- seat / unseat -------------------------------------------------------
-- Officer sends the target + the vehicle netId + seat they picked; we validate
-- and tell the target to warp in / out.
RegisterNetEvent('flrp_leotools:seat', function(target, vehNet, seat)
  local src = source
  target = tonumber(target)
  if not isLeo(src) or not target or not GetPlayerName(target) then return end
  if not within(src, target, FLRP_LEO.Reach) then
    return TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'error', body = 'Nobody in reach to seat.' })
  end
  if dragged[target] then dragged[target] = nil; TriggerClientEvent('flrp_leotools:drag', target, nil, false) end
  TriggerClientEvent('flrp_leotools:seat', target, vehNet, tonumber(seat) or 1)
  log(src, target, 'seated')
end)

RegisterNetEvent('flrp_leotools:unseat', function(target)
  local src = source
  target = tonumber(target)
  if not isLeo(src) or not target or not GetPlayerName(target) then return end
  TriggerClientEvent('flrp_leotools:unseat', target)
end)

-- ---- search (ID + what's on their person) --------------------------------
local pendingSearch = {}  -- [targetSrc] = { officer = src, expires = os.time()+N }

local function money(cents)
  local d = math.floor((tonumber(cents) or 0) / 100)
  local s = tostring(d)
  local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
  return '$' .. out
end

local BLUE = { 90, 160, 255 }
local function line(dst, tag, val)
  TriggerClientEvent('chat:addMessage', dst, { color = BLUE, multiline = true, args = { tag, val } })
end

RegisterNetEvent('flrp_leotools:search', function(target)
  local src = source
  target = tonumber(target)
  if not isLeo(src) or not target or not GetPlayerName(target) then return end
  if not within(src, target, FLRP_LEO.Reach) then
    return TriggerClientEvent('flrp_notify:toast', src, { title = 'LEO', kind = 'error', body = 'No one in reach to search.' })
  end
  pendingSearch[target] = { officer = src, expires = os.time() + 10 }
  TriggerClientEvent('flrp_leotools:collect', target, src)   -- ask target for carried weapons
end)

RegisterNetEvent('flrp_leotools:collected', function(officer, weapons)
  local target = source
  officer = tonumber(officer)
  local p = pendingSearch[target]
  if not p or p.officer ~= officer or os.time() > p.expires then return end -- must be a real pending search
  pendingSearch[target] = nil
  if not isLeo(officer) or not GetPlayerName(officer) then return end

  local bal = 0; pcall(function() bal = exports.flrp_economy:GetBalance(target) or 0 end)
  local pidNum; pcall(function() pidNum = exports.flrp_core:GetPlayerId(target) end)
  weapons = type(weapons) == 'table' and weapons or {}

  line(officer, 'SEARCH', ('%s  (ID %s)'):format(name(target), tostring(pidNum or target)))
  line(officer, '  Wallet', money(bal))
  line(officer, '  Cuffed', cuffed[target] and 'Yes' or 'No')
  line(officer, '  Weapons', #weapons > 0 and table.concat(weapons, ', ') or 'None')

  TriggerClientEvent('flrp_notify:toast', target, { title = 'LEO', kind = 'info', body = name(officer) .. ' searched you.' })
  log(officer, target, 'searched')
end)

AddEventHandler('playerDropped', function()
  local src = source
  cuffed[src] = nil
  dragged[src] = nil
  pendingSearch[src] = nil
  for t, officer in pairs(dragged) do
    if officer == src then dragged[t] = nil; TriggerClientEvent('flrp_leotools:drag', t, nil, false) end
  end
end)
