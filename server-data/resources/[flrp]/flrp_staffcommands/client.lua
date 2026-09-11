local frozen,jail,busy=false,nil,false
CreateThread(function()
    for name,help in pairs({tp='[ID] to go to them; [player ID] [destination ID] to move them',
        ['return']='[ID] return to the saved staff teleport position',freeze='[ID] toggle frozen state',
        announce='[message] announce to the server',clearveh='[seconds] clear unoccupied civilian vehicles',
        fullclearveh='[seconds] clear all unoccupied vehicles',staffjail='[ID] [jobs] assign staff cleaning jobs',
        unstaffjail='[ID] release staff jail'}) do TriggerEvent('chat:addSuggestion','/'..name,'Staff: '..help) end
end)
AddEventHandler('playerSpawned',function() TriggerServerEvent('flrp_staffcommands:ready') end)
RegisterNetEvent('flrp_staffcommands:move',function(p)
    if source~=65535 then return end
    local ped=PlayerPedId()
    if IsPedInAnyVehicle(ped,false) then
        TaskLeaveVehicle(ped,GetVehiclePedIsIn(ped,false),16)
        local deadline=GetGameTimer()+2000
        while IsPedInAnyVehicle(ped,false) and GetGameTimer()<deadline do Wait(0) end
    end
    RequestCollisionAtCoord(p.x,p.y,p.z)
    SetEntityCoords(ped,p.x,p.y,p.z,false,false,false,false)
    SetEntityHeading(ped,p.h or 0)
end)
RegisterNetEvent('flrp_staffcommands:freeze',function(value)
    if source~=65535 then return end
    frozen=value;FreezeEntityPosition(PlayerPedId(),value)
end)
RegisterNetEvent('flrp_staffcommands:announce',function(text)
    if source~=65535 then return end
    BeginTextCommandThefeedPost('STRING');AddTextComponentSubstringPlayerName(text);EndTextCommandThefeedPostTicker(false,true)
end)
RegisterNetEvent('flrp_staffcommands:jail',function(record)
    if source~=65535 then return end
    jail=record or nil;busy=false;ClearPedTasks(PlayerPedId())
end)
RegisterNetEvent('flrp_staffcommands:work',function()
    if source~=65535 or not jail or busy then return end
    busy=true;TaskStartScenarioInPlace(PlayerPedId(),'WORLD_HUMAN_JANITOR',0,true)
    Wait((STAFF.jobSeconds+1)*1000)
    ClearPedTasks(PlayerPedId());busy=false;TriggerServerEvent('flrp_staffcommands:done')
end)
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(3000);TriggerServerEvent('flrp_staffcommands:ready')
    while true do
        if frozen or jail then
            Wait(0)
            if frozen then DisableAllControlActions(0);EnableControlAction(0,245,true);FreezeEntityPosition(PlayerPedId(),true) end
            if jail then
                DisablePlayerFiring(PlayerId(),true)
                for _,control in ipairs({24,25,23,37,140,141,142,257,263,264}) do DisableControlAction(0,control,true) end
                local p=STAFF.jobs[jail.job]
                DrawMarker(1,p.x,p.y,p.z-1,0,0,0,0,0,0,1.0,1.0,0.25,255,180,60,150,false,false,2,false,nil,nil,false)
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(('Staff jail: %d jobs left. %s'):format(jail.remaining,busy and 'Cleaning...' or 'Walk to the marker and press ~INPUT_CONTEXT~ to clean.'))
                EndTextCommandDisplayHelp(0,false,true,-1)
                if not busy and #(GetEntityCoords(PlayerPedId())-vector3(p.x,p.y,p.z))<2.0 and IsControlJustPressed(0,38) then TriggerServerEvent('flrp_staffcommands:work') end
            end
        else Wait(250) end
    end
end)
AddEventHandler('onResourceStop',function(r)
    if r==GetCurrentResourceName() then FreezeEntityPosition(PlayerPedId(),false);ClearPedTasks(PlayerPedId()) end
end)
