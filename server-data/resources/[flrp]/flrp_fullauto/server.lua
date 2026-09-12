-- Server resolves main-guild roles; neither client flags nor broad staff ACEs grant access.
local cache, pending = {}, {}
local sniperHashes = {}
for _, name in ipairs(FLRP_FULLAUTO.Snipers) do
    sniperHashes[GetHashKey(name) & 0xffffffff] = true
end
local function resolve(src)
    src = tonumber(src)
    if not src or src <= 0 then return {auto=false, sniper=false} end
    local now = GetGameTimer()
    if cache[src] and now < cache[src].expires then return cache[src] end
    if pending[src] then return {auto=false, sniper=false} end
    pending[src] = true
    local ok, roles = pcall(function() return exports.flrp_access:GetDiscordRoleIds(src) end)
    pending[src] = nil
    local result = {auto=false, sniper=false, expires=now + 5000}
    if ok and type(roles) == 'table' then
        for _, role in ipairs(roles) do
            role = tostring(role)
            result.sniper = result.sniper or FLRP_FULLAUTO.SniperRoles[role] == true
        end
        result.expires = now + 30000
    end
    if GetPlayerName(src) then cache[src] = result end
    return result
end
RegisterNetEvent('flrp_fullauto:check', function()
    local src = source
    local access = resolve(src)
    TriggerClientEvent('flrp_fullauto:set', src, IsPlayerAceAllowed(src, FLRP_FULLAUTO.Ace), access.sniper)
end)
AddEventHandler('playerDropped', function() cache[source] = nil; pending[source] = nil end)
exports('IsAllowed', function(src)
    src = tonumber(src)
    return src and IsPlayerAceAllowed(src, FLRP_FULLAUTO.Ace) or false
end)
exports('IsSniperAllowed', function(src) return resolve(src).sniper end)
-- Damage hooks must not yield to HTTP. An absent/expired decision denies damage
-- until the client's periodic role check refreshes it.
AddEventHandler('weaponDamageEvent', function(sender, data)
    local hash = tonumber(data.weaponType)
    if hash and sniperHashes[hash & 0xffffffff] then
        local access = cache[tonumber(sender)]
        if not access or not access.sniper or GetGameTimer() >= access.expires then CancelEvent() end
    end
end)
