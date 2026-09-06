-- ==========================================================================
-- FLRP :: flrp_dutycounter/client.lua — feeds the HUD counter NUI, and lets
-- each player move/resize it with /counter (layout saved per machine via KVP).
-- ==========================================================================

local DEFAULT = { x = 22.4, y = 78.0, scale = 1.0 }   -- % of screen (top-left of card)
local editing = false

local function layout()
  local function f(key, def)
    local v = GetResourceKvpFloat('flrp_dutycounter:' .. key)
    return (v ~= nil and v ~= 0.0) and v or def
  end
  return { x = f('x', DEFAULT.x), y = f('y', DEFAULT.y), scale = f('scale', DEFAULT.scale) }
end

local function pushLayout()
  SendNUIMessage({ type = 'layout', layout = layout() })
end

local function endEdit()
  if not editing then return end
  editing = false
  SetNuiFocus(false, false)
end

RegisterNetEvent('flrp_dutycounter:update', function(data)
  SendNUIMessage({
    type = 'update',
    leo   = (data and data.leo)   or 0,
    fire  = (data and data.fire)  or 0,
    staff = (data and data.staff) or 0,
  })
end)

-- /counter — enter layout edit mode (drag to move, +/- to resize, save/reset).
RegisterCommand('counter', function()
  editing = true
  SetNuiFocus(true, true)
  SendNUIMessage({ type = 'edit', on = true, layout = layout() })
end, false)
TriggerEvent('chat:addSuggestion', '/counter', 'Move & resize the on-duty unit counter')

RegisterNUICallback('dccSave', function(data, cb)
  local x, y, s = tonumber(data and data.x), tonumber(data and data.y), tonumber(data and data.scale)
  if x then SetResourceKvpFloat('flrp_dutycounter:x', x + 0.0) end
  if y then SetResourceKvpFloat('flrp_dutycounter:y', y + 0.0) end
  if s then SetResourceKvpFloat('flrp_dutycounter:scale', s + 0.0) end
  endEdit()
  cb({ ok = true })
end)

RegisterNUICallback('dccCancel', function(_, cb) endEdit(); pushLayout(); cb({ ok = true }) end)
RegisterNUICallback('dccReset', function(_, cb)
  DeleteResourceKvp('flrp_dutycounter:x')
  DeleteResourceKvp('flrp_dutycounter:y')
  DeleteResourceKvp('flrp_dutycounter:scale')
  pushLayout()
  cb({ ok = true })
end)

AddEventHandler('onClientResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  Wait(500)
  pushLayout()
  TriggerServerEvent('flrp_dutycounter:request')
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and editing then SetNuiFocus(false, false) end
end)

-- Ask again once the player is fully in the session (covers first spawn).
CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  Wait(1000)
  pushLayout()
  TriggerServerEvent('flrp_dutycounter:request')
end)
