-- ==========================================================================
-- FLRP :: flrp_leoblips/client.lua — draw one blip per on-duty officer
-- ==========================================================================
-- Keeps a blip per remote officer (keyed by server id), moves it each update,
-- and removes blips for anyone no longer in the payload (went off duty, left,
-- or we lost permission to see them — the server sends {} in that case).
-- ==========================================================================

local blips = {}   -- [src] = blip handle

local function setLabel(blip, label)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString(label)
  EndTextCommandSetBlipName(blip)
end

local function ensureBlip(u)
  local b = blips[u.src]
  if not b or not DoesBlipExist(b) then
    b = AddBlipForCoord(u.x, u.y, u.z)
    SetBlipSprite(b, FLRP_BLIPS.Sprite)
    SetBlipScale(b, FLRP_BLIPS.Scale)
    SetBlipAsShortRange(b, FLRP_BLIPS.ShortRange)
    SetBlipCategory(b, 7)          -- groups them under their own map-legend heading
    blips[u.src] = b
  else
    SetBlipCoords(b, u.x, u.y, u.z)
  end
  SetBlipColour(b, u.colour or FLRP_BLIPS.DefaultColour)
  setLabel(b, u.label or ('Unit ' .. u.src))
end

RegisterNetEvent('flrp_leoblips:update', function(units)
  local me = GetPlayerServerId(PlayerId())
  local seen = {}
  if type(units) == 'table' then
    for _, u in ipairs(units) do
      if u.src and u.src ~= me then      -- never draw yourself
        ensureBlip(u)
        seen[u.src] = true
      end
    end
  end
  -- drop anything not in this payload
  for src, b in pairs(blips) do
    if not seen[src] then
      if DoesBlipExist(b) then RemoveBlip(b) end
      blips[src] = nil
    end
  end
end)

-- Clean up on resource stop so no orphan blips are left on the map.
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for _, b in pairs(blips) do
    if DoesBlipExist(b) then RemoveBlip(b) end
  end
  blips = {}
end)
