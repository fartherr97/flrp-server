-- ==========================================================================
-- FLRP :: flrp_leoblips/server.lua — push on-duty LEO positions to viewers
-- ==========================================================================
-- Each tick: read the live roster, collect every CONNECTED on-duty LEO with
-- their current coords (OneSync gives the server entity positions), then send
-- the list to viewers (on-duty LEO + staff). Everyone else receives an empty
-- list, which makes their client clear any blips they were shown previously
-- (e.g. someone who just went off duty).
-- ==========================================================================

local function colourFor(entity)
  return FLRP_BLIPS.Colours[entity or ''] or FLRP_BLIPS.DefaultColour
end

local function buildUnits()
  local ok, roster = pcall(function() return exports.flrp_duty:GetOnDutyRoster() end)
  if not ok or type(roster) ~= 'table' then return {}, {} end

  local units, viewers = {}, {}
  for _, u in ipairs(roster) do
    if u.online and u.src and u.department then      -- FLRP LEO dept only
      viewers[u.src] = true
      local ped = GetPlayerPed(u.src)
      if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        units[#units + 1] = {
          src      = u.src,
          x = c.x, y = c.y, z = c.z,
          colour   = colourFor(u.entity),
          label    = (u.callsign and u.callsign ~= '' and (tostring(u.callsign) .. ' | ') or '')
                     .. (u.name or ('Unit ' .. u.src)),
        }
      end
    end
  end
  return units, viewers
end

CreateThread(function()
  while true do
    Wait(FLRP_BLIPS.UpdateMs)
    local units, viewers = buildUnits()
    for _, pid in ipairs(GetPlayers()) do
      local src = tonumber(pid)
      if src then
        local canSee = viewers[src] or IsPlayerAceAllowed(src, FLRP_BLIPS.StaffAce)
        TriggerClientEvent('flrp_leoblips:update', src, canSee and units or {})
      end
    end
  end
end)
