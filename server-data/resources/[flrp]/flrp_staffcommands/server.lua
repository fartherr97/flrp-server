local returns, frozen, jailed, working = {}, {}, {}, {}
local sentences = json.decode(GetResourceKvpString('sentences') or '{}') or {}
local clearing = false
local handlers = {}
local function persist() SetResourceKvp('sentences', json.encode(sentences)) end
local function tell(id, text) TriggerClientEvent('chat:addMessage', id, {args={'STAFF',text},color={255,180,60}}) end
local function allowed(id) return id == 0 or IsPlayerAceAllowed(id, STAFF.ace) end
local function identity(id) return GetPlayerIdentifierByType(id, 'license') end
local function target(raw)
    local id=tonumber(raw)
    if id and id>0 and id%1==0 and GetPlayerName(id) then return id end
end
local function position(id)
    local ped=GetPlayerPed(id)
    if ped==0 or not DoesEntityExist(ped) then return end
    local p=GetEntityCoords(ped)
    return {x=p.x,y=p.y,z=p.z,h=GetEntityHeading(ped),bucket=GetPlayerRoutingBucket(id)}
end
local function move(id,p)
    SetPlayerRoutingBucket(id,p.bucket or 0)
    if GetVehiclePedIsIn(GetPlayerPed(id),false)==0 then SetEntityCoords(GetPlayerPed(id),p.x,p.y,p.z,false,false,false,false) end
    TriggerClientEvent('flrp_staffcommands:move',id,p)
end
local function command(name,handler)
    handlers[name]=handler
    for _,existing in ipairs(GetRegisteredCommands()) do
        if existing.name==name then print('[flrp_staffcommands] Existing command preserved: /'..name);return end
    end
    RegisterCommand(name,function(src,args)
        if not allowed(src) then return tell(src,'Staff access required.') end
        handler(src,args)
        print(('[flrp_staffcommands] %s ran /%s'):format(src,name))
    end,false)
end
command('tp',function(src,args)
    local subject,destination
    if #args==1 then subject=target(src);destination=target(args[1])
    elseif #args==2 then subject=target(args[1]);destination=target(args[2]) end
    if not subject or not destination or subject==destination then return tell(src,'Usage: /tp [destination ID] or /tp [player ID] [destination ID]') end
    if jailed[subject] or jailed[destination] then return tell(src,'Release staff jail before teleporting.') end
    local origin,finish=position(subject),position(destination)
    if not origin or not finish then return tell(src,'Player is not spawned.') end
    returns[subject]=origin; finish.x=finish.x+1.5
    move(subject,finish);tell(src,'Teleported player '..subject..' to '..destination..'.')
end)
exports('GetSentence',function(id)
    id=tonumber(id)
    if not id or not GetPlayerName(id) then return 0 end
    local key=identity(id)
    local record=key and sentences[key]
    return record and record.remaining or 0
end)
exports('ManageJail',function(src,id,jobs,releaseEarly)
    if not allowed(src) then return {ok=false,error='Staff only.'} end
    id=target(id)
    if not id then return {ok=false,error='Player not online.'} end
    local key=identity(id)
    if not key then return {ok=false,error='Player is not ready.'} end
    if releaseEarly then
        handlers.unstaffjail(src,{tostring(id)})
        return {ok=sentences[key]==nil}
    end
    if sentences[key] then return {ok=false,error='Player already has a staff-jail sentence.'} end
    handlers.staffjail(src,{tostring(id),tostring(jobs)})
    return sentences[key] and {ok=true} or {ok=false,error='Unable to assign staff jail. Check jobs and existing custody.'}
end)
command('return',function(src,args)
    local id=target(args[1])
    if not id or not returns[id] then return tell(src,'No saved teleport location for that player.') end
    if jailed[id] then return tell(src,'Release staff jail first.') end
    move(id,returns[id]);returns[id]=nil;tell(src,'Returned player '..id..'.')
end)
command('freeze',function(src,args)
    local id=target(args[1]);if not id then return tell(src,'Usage: /freeze [ID]') end
    frozen[id]=not frozen[id]
    FreezeEntityPosition(GetPlayerPed(id),frozen[id])
    TriggerClientEvent('flrp_staffcommands:freeze',id,frozen[id])
    tell(src,('Player %d %s.'):format(id,frozen[id] and 'frozen' or 'unfrozen'))
end)
command('announce',function(src,args)
    local message=table.concat(args,' '):sub(1,500)
    if message=='' then return tell(src,'Usage: /announce [message]') end
    tell(-1,'ANNOUNCEMENT: '..message)
    TriggerClientEvent('flrp_staffcommands:announce',-1,message)
end)

-- Use resource vehicle metadata to preserve add-on emergency fleets too.
local emergency={}
for _,name in ipairs(json.decode(LoadResourceFile(GetCurrentResourceName(),'emergency-models.json') or '[]') or {}) do emergency[GetHashKey(name)]=true end
for name in ('ambulance fbi fbi2 firetruk lguard pbus police police2 police3 police4 policeb policet polmav pranger riot riot2 sheriff sheriff2 policeold1 policeold2'):gmatch('%S+') do emergency[GetHashKey(name)]=true end
local function loadEmergencyModels()
    for i=0,GetNumResources()-1 do
        local resource=GetResourceByFindIndex(i)
        for j=0,GetNumResourceMetadata(resource,'data_file')-1 do
            if GetResourceMetadata(resource,'data_file',j)=='VEHICLE_METADATA_FILE' then
                local extra=GetResourceMetadata(resource,'data_file_extra',j)
                local ok,files=pcall(json.decode,extra or '[]')
                if ok and type(files)=='table' then
                    for _,file in ipairs(files) do
                        local xml=LoadResourceFile(resource,file)
                        if xml then
                            for model,details in xml:gmatch('<modelName>(.-)</modelName>(.-)</vehicleClass>') do
                                if details:find('<vehicleClass>VC_EMERGENCY',1,true) then emergency[GetHashKey(model)]=true end
                            end
                        end
                    end
                end
            end
        end
    end
end
local function clear(src,args,all)
    local seconds=tonumber(args[1] or '30')
    if not seconds or seconds%1~=0 or seconds<0 or seconds>600 then return tell(src,'Delay must be 0–600 seconds.') end
    if clearing then return tell(src,'A vehicle clear is already scheduled.') end
    clearing=true
    tell(-1,('%s vehicles will be cleared in %d seconds. Occupied vehicles are protected.'):format(all and 'All unoccupied' or 'Unoccupied civilian',seconds))
    SetTimeout(seconds*1000,function()
        loadEmergencyModels()
        local occupied={}
        for _,ped in ipairs(GetAllPeds()) do
            local v=GetVehiclePedIsIn(ped,false);if v~=0 then occupied[v]=true end
        end
        local count=0
        for _,v in ipairs(GetAllVehicles()) do
            if not occupied[v] and (all or not emergency[GetEntityModel(v)]) then DeleteEntity(v);count=count+1 end
        end
        clearing=false;tell(-1,('Vehicle clear completed: %d vehicles.'):format(count))
    end)
end
command('clearveh',function(s,a) clear(s,a,false) end)
command('fullclearveh',function(s,a) clear(s,a,true) end)

local function sendJail(id,record) TriggerClientEvent('flrp_staffcommands:jail',id,record and {remaining=record.remaining,job=record.job} or false) end
local function release(id)
    local key=jailed[id];local record=key and sentences[key]
    if not record then return false end
    jailed[id]=nil;working[id]=nil;sentences[key]=nil;persist()
    sendJail(id,false);move(id,record.origin);tell(id,'Your staff jail is complete.')
    return true
end
command('staffjail',function(src,args)
    local id=target(args[1]);local jobs=tonumber(args[2])
    if not id or not jobs or jobs%1~=0 or jobs<1 or jobs>STAFF.maxJobs then return tell(src,'Usage: /staffjail [ID] [jobs 1–200]') end
    if GetResourceState('flrp_jail')=='started' and exports.flrp_jail:IsInCustody(id) then return tell(src,'Release timed custody first.') end
    local key=identity(id);local origin=position(id)
    if not key or not origin then return tell(src,'Player is not ready.') end
    if sentences[key] then return tell(src,'Player already has a staff-jail sentence.') end
    sentences[key]={remaining=jobs,job=1,origin=origin};jailed[id]=key;persist()
    frozen[id]=nil;FreezeEntityPosition(GetPlayerPed(id),false);TriggerClientEvent('flrp_staffcommands:freeze',id,false)
    move(id,STAFF.jail);sendJail(id,sentences[key]);tell(src,'Assigned '..jobs..' staff-jail jobs to '..id..'.')
end)
command('unstaffjail',function(src,args)
    local id=target(args[1]);if not id or not release(id) then return tell(src,'Player is not in staff jail.') end
    tell(src,'Released player '..id..'.')
end)
RegisterNetEvent('flrp_staffcommands:ready',function()
    local id=source;local key=identity(id)
    if key and sentences[key] then jailed[id]=key;move(id,STAFF.jail);sendJail(id,sentences[key]) end
end)
RegisterNetEvent('flrp_staffcommands:work',function()
    local id=source;local record=sentences[jailed[id] or '']
    if not record or working[id] then return end
    local p=GetEntityCoords(GetPlayerPed(id));local spot=STAFF.jobs[record.job]
    if #(p-vector3(spot.x,spot.y,spot.z))>2.5 then return end
    working[id]={started=os.time(),job=record.job,key=jailed[id]}
    TriggerClientEvent('flrp_staffcommands:work',id)
end)
RegisterNetEvent('flrp_staffcommands:done',function()
    local id=source;local work=working[id];local record=sentences[jailed[id] or '']
    if not work or not record or work.key~=jailed[id] or work.job~=record.job then return end
    if os.time()-work.started<STAFF.jobSeconds then return end
    working[id]=nil
    local spot=STAFF.jobs[record.job];local p=GetEntityCoords(GetPlayerPed(id))
    if #(p-vector3(spot.x,spot.y,spot.z))>2.5 then return sendJail(id,record) end
    record.remaining=record.remaining-1
    if record.remaining<=0 then return release(id) end
    record.job=record.job%#STAFF.jobs+1;persist();sendJail(id,record)
end)
CreateThread(function()
    while true do
        Wait(1000)
        for id,key in pairs(jailed) do
            local p=position(id)
            if p and sentences[key] and (#(vector3(p.x,p.y,p.z)-vector3(STAFF.jail.x,STAFF.jail.y,STAFF.jail.z))>STAFF.radius or p.bucket~=0) then move(id,STAFF.jail) end
        end
    end
end)
AddEventHandler('playerDropped',function() returns[source]=nil;frozen[source]=nil;jailed[source]=nil;working[source]=nil end)
AddEventHandler('onResourceStop',function(r)
    if r~=GetCurrentResourceName() then return end
    for id in pairs(frozen) do FreezeEntityPosition(GetPlayerPed(id),false) end
end)
