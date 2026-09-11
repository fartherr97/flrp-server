local active, target, selected, probe = false, 0, nil, nil
local notice, noticeUntil, confirmUntil = '', 0, 0

local function message(text)
    notice, noticeUntil = text, GetGameTimer() + 5000
end
local function close()
    active, target, selected, probe, confirmUntil = false, 0, nil, nil, 0
end
local function text(x, y, value, scale)
    SetTextFont(0)
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextColour(240, 245, 250, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(value)
    EndTextCommandDisplayText(x, y)
end
local function selectable(entity)
    return entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 3
end

RegisterNetEvent('flrp_entityviewer:toggle', function()
    if active then close() else active = true; message('Point at a prop and press E to select it.') end
end)
RegisterNetEvent('flrp_entityviewer:result', function(value)
    message(value)
    selected, confirmUntil = nil, 0
    if not active then TriggerEvent('chat:addMessage', {args={'ENTITY VIEWER', value}}) end
end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then close() end end)

CreateThread(function()
    while true do
        if not active then Wait(250) else
            Wait(0)
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 178, true)
            if IsControlJustPressed(0, 177) or IsEntityDead(PlayerPedId()) then close() end
            if active then
                if not selected then
                    if not probe then
                        local p, r = GetGameplayCamCoord(), GetGameplayCamRot(2)
                        local pitch, yaw = math.rad(r.x), math.rad(r.z)
                        local dx, dy, dz = -math.sin(yaw)*math.cos(pitch), math.cos(yaw)*math.cos(pitch), math.sin(pitch)
                        -- Include world, peds and vehicles so the ray cannot select through them.
                        probe = StartShapeTestLosProbe(p.x,p.y,p.z,p.x+dx*30,p.y+dy*30,p.z+dz*30,31,PlayerPedId(),0)
                    else
                        local status, hit, _, _, entity = GetShapeTestResult(probe)
                        if status ~= 1 then
                            probe = nil
                            target = status == 2 and (hit == true or hit == 1) and selectable(entity) and entity or 0
                        end
                    end
                    if IsDisabledControlJustPressed(0,38) and selectable(target) then
                        selected = {entity=target, model=GetEntityModel(target), net=NetworkGetEntityIsNetworked(target) and NetworkGetNetworkIdFromEntity(target) or 0}
                    end
                end
                local entity = selected and selected.entity or target
                if selected and (not selectable(entity) or GetEntityModel(entity) ~= selected.model or (selected.net > 0 and NetworkGetNetworkIdFromEntity(entity) ~= selected.net)) then
                    selected = nil; entity = 0; message('Selection no longer exists.')
                end
                DrawRect(0.5,0.5,0.003,0.003,50,220,190,230)
                DrawRect(0.19,0.17,0.35,0.23,12,20,28,220)
                text(0.025,0.066,'ENTITY VIEWER',0.43)
                text(0.025,0.106,selected and 'SELECTED | E: release | DELETE: delete' or 'Aim at a prop | E: select')
                text(0.025,0.134,'BACKSPACE: exit | Range: 30 metres')
                if selectable(entity) then
                    local p = GetEntityCoords(entity)
                    DrawMarker(28,p.x,p.y,p.z,0.0,0.0,0.0,0.0,0.0,0.0,0.2,0.2,0.2,50,220,190,180,false,false,2,false,nil,nil,false)
                    text(0.025,0.166,('Model: %s | %.1f, %.1f, %.1f'):format(GetEntityModel(entity),p.x,p.y,p.z))
                    text(0.025,0.194,NetworkGetEntityIsNetworked(entity) and 'Network prop | deletion syncs to other players' or 'Local / map prop | inspection only')
                    if selected and IsDisabledControlJustPressed(0,178) then
                        if selected.net == 0 then message('Map/local props cannot be deleted with this tool.')
                        elseif confirmUntil > GetGameTimer() then
                            TriggerServerEvent('flrp_entityviewer:delete',selected.net,selected.model)
                            selected, confirmUntil = nil, 0
                            message('Requesting server deletion...')
                        else confirmUntil = GetGameTimer()+3000; message('Press DELETE again within 3 seconds to confirm.') end
                    elseif selected and IsDisabledControlJustPressed(0,38) then
                        -- The press that initially selected it must not also release it.
                        if selected.ready then selected, confirmUntil = nil, 0 end
                    end
                    if selected then selected.ready = true end
                else text(0.025,0.166,'No prop targeted') end
                if noticeUntil > GetGameTimer() then text(0.025,0.235,notice,0.29) end
            end
        end
    end
end)
