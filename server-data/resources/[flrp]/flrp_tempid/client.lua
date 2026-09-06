-- ==========================================================================
-- FLRP :: flrp_tempid/client.lua — draw nearby server IDs overhead for 5s
-- ==========================================================================

local showUntil = 0

-- World-space label above a ped.
local function draw3dText(x, y, z, text)
  local onScreen, sx, sy = World3dToScreen2d(x, y, z)
  if not onScreen then return end
  local dist = #(GetGameplayCamCoord() - vector3(x, y, z))
  local scale = math.max(0.28, 0.60 - dist * 0.008)   -- shrink slightly with distance

  SetTextScale(0.0, scale)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextColour(255, 255, 255, 220)
  SetTextDropshadow(0, 0, 0, 0, 255)
  SetTextEdge(2, 0, 0, 0, 180)
  SetTextDropShadow()
  SetTextOutline()
  SetTextCentre(true)
  SetTextEntry('STRING')
  AddTextComponentString(text)
  DrawText(sx, sy)
end

-- Server confirmed we're LEO — start the reveal window.
RegisterNetEvent('flrp_tempid:show', function()
  showUntil = GetGameTimer() + (FLRP_TEMPID.Duration or 5000)
end)

CreateThread(function()
  local range = FLRP_TEMPID.Range or 30.0
  local prefix = FLRP_TEMPID.Label or 'ID'
  while true do
    if GetGameTimer() < showUntil then
      local me = PlayerPedId()
      local mc = GetEntityCoords(me)
      for _, p in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(p)
        if ped ~= me and ped ~= 0 and DoesEntityExist(ped) then
          local c = GetEntityCoords(ped)
          if #(mc - c) <= range then
            draw3dText(c.x, c.y, c.z + 1.05, ('%s %d'):format(prefix, GetPlayerServerId(p)))
          end
        end
      end
      Wait(0)
    else
      Wait(200)
    end
  end
end)

local lastUse = 0
local function useTempId()
  local now = GetGameTimer()
  if now - lastUse < (FLRP_TEMPID.Cooldown or 0) then return end
  lastUse = now
  TriggerServerEvent('flrp_tempid:use')
end

RegisterCommand(FLRP_TEMPID.Command, useTempId, false)
RegisterKeyMapping(FLRP_TEMPID.Command, 'LEO: Reveal nearby player IDs (5s)', 'keyboard', FLRP_TEMPID.Key)
TriggerEvent('chat:addSuggestion', '/' .. FLRP_TEMPID.Command, "LEO: briefly show nearby players' IDs above their heads")
