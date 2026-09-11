local cooldown = {}
local function allowed(src) return src > 0 and IsPlayerAceAllowed(src, 'flrp.staff.moderate') end
local function reply(src, message) TriggerClientEvent('flrp_entityviewer:result', src, message) end

RegisterCommand('entityviewer', function(src)
    if not allowed(src) then return reply(src, 'Staff access required.') end
    TriggerClientEvent('flrp_entityviewer:toggle', src)
end, false)

RegisterNetEvent('flrp_entityviewer:delete', function(netId, model)
    local src = source
    if not allowed(src) then return reply(src, 'Staff access required.') end
    local now = GetGameTimer()
    if cooldown[src] and now - cooldown[src] < 1000 then return reply(src, 'Wait a moment before deleting another object.') end
    cooldown[src] = now
    if type(netId) ~= 'number' or netId % 1 ~= 0 or netId <= 0 or type(model) ~= 'number' then
        return reply(src, 'Invalid object.')
    end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(src)
    if entity == 0 or not DoesEntityExist(entity) or ped == 0 then return reply(src, 'Object no longer exists.') end
    if GetEntityType(entity) ~= 3 or GetEntityModel(entity) ~= model then return reply(src, 'Only the selected prop can be deleted.') end
    if GetEntityRoutingBucket(entity) ~= GetPlayerRoutingBucket(src) then return reply(src, 'Object is in another routing bucket.') end
    local p, e = GetEntityCoords(ped), GetEntityCoords(entity)
    if (p.x-e.x)^2 + (p.y-e.y)^2 + (p.z-e.z)^2 > 30^2 then return reply(src, 'Move within 30 metres of the object.') end
    DeleteEntity(entity)
    print(('[flrp_entityviewer] staff=%s netId=%s model=%s position=%.2f,%.2f,%.2f delete requested'):format(src, netId, model, e.x, e.y, e.z))
    SetTimeout(500, function()
        if not GetPlayerName(src) then return end
        local current = NetworkGetEntityFromNetworkId(netId)
        reply(src, (current == 0 or not DoesEntityExist(current)) and 'Object deleted.' or 'Deletion could not be confirmed; the owning script may recreate this object.')
    end)
end)

AddEventHandler('playerDropped', function() cooldown[source] = nil end)
