-- ==========================================================================
-- FLRP :: flrp_gunstores/client/main.lua — store proximity + NUI bridge
-- ==========================================================================
-- Draws store markers/blips, opens the NUI when the player interacts near a
-- store, and relays catalog/purchase messages. All authority is server-side;
-- this client only presents the UI and forwards requests.
-- ==========================================================================

local isOpen = false
local nearStore = nil

-- Blips for stores.
CreateThread(function()
  for _, store in ipairs(FLRPG.Config.Stores) do
    if store.blip and store.blip.enabled then
      local blip = AddBlipForCoord(store.coords.x, store.coords.y, store.coords.z)
      SetBlipSprite(blip, store.blip.sprite or 110)
      SetBlipColour(blip, store.blip.color or 1)
      SetBlipScale(blip, store.blip.scale or 0.8)
      SetBlipAsShortRange(blip, true)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentSubstringPlayerName(store.label or 'Gun Store')
      EndTextCommandSetBlipName(blip)
    end
  end
end)

-- Proximity + interaction loop.
CreateThread(function()
  while true do
    local sleep = 1000
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    nearStore = nil
    for _, store in ipairs(FLRPG.Config.Stores) do
      local d = #(pcoords - vector3(store.coords.x, store.coords.y, store.coords.z))
      if d <= 20.0 then
        sleep = 0
        if FLRPG.Config.ShowMarkers then
          DrawMarker(21, store.coords.x, store.coords.y, store.coords.z + 0.5, 0,0,0, 0,0,0,
            0.4,0.4,0.4, 60,140,220,120, false, true, 2, nil, nil, false)
        end
        if d <= FLRPG.Config.InteractRadius then
          nearStore = store
          if not isOpen then
            DisplayHelpText('Press ~INPUT_CONTEXT~ to browse the gun store')
            if IsControlJustReleased(0, 51) then -- E
              OpenStore(store)
            end
          end
        end
      end
    end
    Wait(sleep)
  end
end)

function DisplayHelpText(text)
  BeginTextCommandDisplayHelp('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayHelp(0, false, true, -1)
end

function OpenStore(store)
  isOpen = true
  SetNuiFocus(true, true)
  TriggerServerEvent('flrp_gunstores:requestCatalog')
  SendNUIMessage({ action = 'open', store = { id = store.id, label = store.label } })
end

RegisterNetEvent('flrp_gunstores:catalog', function(catalog, balanceCents)
  SendNUIMessage({ action = 'catalog', catalog = catalog, balanceCents = balanceCents })
end)

RegisterNetEvent('flrp_gunstores:purchaseResult', function(ok, res)
  SendNUIMessage({ action = 'purchaseResult', ok = ok, result = res })
  -- Refresh catalog + balance + owned flags after any purchase attempt while
  -- the menu is still open.
  if isOpen then TriggerServerEvent('flrp_gunstores:requestCatalog') end
end)

-- NUI callbacks.
RegisterNUICallback('buy', function(data, cb)
  if nearStore and data and data.weaponName then
    TriggerServerEvent('flrp_gunstores:purchase', data.weaponName, nearStore.id)
  end
  cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
  isOpen = false
  SetNuiFocus(false, false)
  cb({ ok = true })
end)
