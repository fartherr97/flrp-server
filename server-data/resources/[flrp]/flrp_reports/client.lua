-- ==========================================================================
-- FLRP :: flrp_reports/client.lua — keybind, NUI focus, toast → J jump
-- ==========================================================================

local isOpen     = false
local pending    = {}   -- reqId -> callback
local seq        = 0
local jumpTo     = nil  -- report id the next J press should open
local jumpUntil  = 0

local function request(action, payload, cb)
  seq = seq + 1
  pending[seq] = cb
  TriggerServerEvent('flrp_reports:req', action, payload or {}, seq)
end

RegisterNetEvent('flrp_reports:res', function(id, data)
  local cb = pending[id]
  pending[id] = nil
  if cb then cb(data) end
end)

local function close()
  isOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

local function open(view, reportId)
  request('state', {}, function(state)
    if not state or not state.ok then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state, view = view, reportId = reportId })
  end)
end

-- J (rebindable in Settings > Key Bindings > FiveM)
RegisterCommand('flrp_reports_toggle', function()
  if isOpen then return close() end
  local rid = nil
  if jumpTo and GetGameTimer() < jumpUntil then rid = jumpTo end
  jumpTo = nil
  open(nil, rid)
end, false)
RegisterKeyMapping('flrp_reports_toggle', 'FLRP: Reports (staff console / player support)', 'keyboard', FLRP_REPORTS.Key)

-- /report, /calladmin
RegisterNetEvent('flrp_reports:open', function(view)
  if not isOpen then open(view) end
end)

-- Toasts (new report for staff; claimed / message / resolved for the player).
-- Any toast carrying a reportId arms J to open that report directly.
RegisterNetEvent('flrp_reports:toast', function(t)
  if type(t) ~= 'table' then return end
  SendNUIMessage({ action = 'toast', toast = t })
  if t.reportId then
    jumpTo = t.reportId
    jumpUntil = GetGameTimer() + ((t.seconds or FLRP_REPORTS.ToastSeconds) * 1000)
  end
end)

-- Something changed server-side; if the menu is open, pull fresh state.
RegisterNetEvent('flrp_reports:refresh', function()
  if not isOpen then return end
  request('state', {}, function(state)
    if state and state.ok then SendNUIMessage({ action = 'state', state = state }) end
  end)
end)

RegisterNUICallback('close', function(_, cb)
  close()
  cb({})
end)

-- Generic NUI -> server bridge. Response is passed straight back to the page.
RegisterNUICallback('req', function(data, cb)
  request(data and data.action, data and data.payload, function(res)
    cb(res or { ok = false, error = 'No response.' })
  end)
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
