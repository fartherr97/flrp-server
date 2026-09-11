-- ==========================================================================
-- FLRP :: flrp_chat/client.lua — floating /me text above the player's head
-- ==========================================================================
-- The server sends flrp_chat:headText(serverId, text) to the players who
-- received the emote. We keep the latest action per player and draw it above
-- their head bone for Head3D.duration ms, only while they are within
-- Head3D.distance of the local camera. One draw thread runs only while there
-- is something to draw, so this costs nothing when nobody is emoting.
-- ==========================================================================

local H3D    = FLRP_CHAT.RP.Head3D or { enabled = false }
local active = {}       -- serverId -> { lines = {...}, expires = ms }
local count  = 0
local SKEL_HEAD = 31086

-- Wrap text into lines of at most H3D.maxLine chars on word boundaries.
local function wrap(text, max)
  local lines, cur = {}, ''
  for word in text:gmatch('%S+') do
    if cur == '' then cur = word
    elseif #cur + 1 + #word <= max then cur = cur .. ' ' .. word
    else lines[#lines + 1] = cur; cur = word end
  end
  if cur ~= '' then lines[#lines + 1] = cur end
  return lines
end

local function drawLine(x, y, z, dy, text)
  SetDrawOrigin(x, y, z, 0)
  SetTextFont(4)
  SetTextProportional(true)
  SetTextScale(H3D.scale or 0.32, H3D.scale or 0.32)
  local c = H3D.colour or { 195, 155, 211 }
  SetTextColour(c[1], c[2], c[3], 235)
  SetTextOutline()
  SetTextCentre(true)
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayText(0.0, dy)
  ClearDrawOrigin()
end

local drawing = false
local function startDrawing()
  if drawing then return end
  drawing = true
  CreateThread(function()
    while count > 0 do
      local now = GetGameTimer()
      local camPos = GetGameplayCamCoords()
      local maxDist = H3D.distance or 20.0
      for sid, e in pairs(active) do
        if now >= e.expires then
          active[sid] = nil; count = count - 1
        else
          local pid = GetPlayerFromServerId(sid)
          local ped = (pid ~= -1) and GetPlayerPed(pid) or 0
          if ped ~= 0 and DoesEntityExist(ped) then
            local head = GetPedBoneCoords(ped, SKEL_HEAD, 0.0, 0.0, 0.0)
            if #(camPos - head) <= maxDist then
              local z = head.z + (H3D.zOffset or 0.45)
              -- stack lines upward so the first line sits highest
              local n = #e.lines
              for i, line in ipairs(e.lines) do
                drawLine(head.x, head.y, z, (i - 1) * 0.024 - (n - 1) * 0.024, line)
              end
            end
          end
        end
      end
      Wait(0)
    end
    drawing = false
  end)
end

RegisterNetEvent('flrp_chat:headText', function(serverId, text)
  if not H3D.enabled then return end
  serverId = tonumber(serverId)
  if not serverId or type(text) ~= 'string' or text == '' then return end
  if not active[serverId] then count = count + 1 end
  active[serverId] = {
    lines   = wrap('* ' .. text, H3D.maxLine or 40),
    expires = GetGameTimer() + (H3D.duration or 8000),
  }
  startDrawing()
end)
