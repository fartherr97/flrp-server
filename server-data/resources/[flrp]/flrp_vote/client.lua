-- ==========================================================================
-- FLRP :: flrp_vote/client.lua — builder focus + full-screen ballot
-- ==========================================================================

local focused = false

local function focus(on)
  focused = on and true or false
  SetNuiFocus(focused, focused)
end

-- /startvote -> ask the server (it checks staff, then opens the builder).
RegisterCommand(FLRP_VOTE.Command, function() TriggerServerEvent('flrp_vote:open') end, false)
TriggerEvent('chat:addSuggestion', '/' .. FLRP_VOTE.Command, 'Start a server-wide vote (AOP, polls, anything)')

-- Server approved the builder (staff only).
RegisterNetEvent('flrp_vote:openConfig', function(limits)
  focus(true)
  SendNUIMessage({ action = 'config', limits = limits or {} })
end)

-- A vote started: full-screen ballot that blocks the screen until they vote.
RegisterNetEvent('flrp_vote:ballot', function(data)
  focus(true)
  SendNUIMessage({ action = 'ballot', ballot = data })
end)

-- Results (or cancel) release focus and show/close the panel.
RegisterNetEvent('flrp_vote:results', function(data)
  focus(false)
  SendNUIMessage({ action = 'results', results = data })
end)
RegisterNetEvent('flrp_vote:cancel', function()
  focus(false)
  SendNUIMessage({ action = 'close' })
end)

-- NUI callbacks -------------------------------------------------------------
RegisterNUICallback('start', function(data, cb)   -- staff submitted a built vote
  focus(false)
  TriggerServerEvent('flrp_vote:start', data or {})
  cb({ ok = true })
end)
RegisterNUICallback('cast', function(data, cb)     -- a player voted
  focus(false)
  TriggerServerEvent('flrp_vote:cast', data and data.index)
  cb({ ok = true })
end)
RegisterNUICallback('dismiss', function(_, cb)     -- close builder / results
  focus(false)
  SendNUIMessage({ action = 'close' })
  cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and focused then SetNuiFocus(false, false) end
end)
