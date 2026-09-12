-- Server-owned dynamic destinations. No client-supplied coordinates are used.
FLRPSpawnDynamic = {}
local D = FLRPSpawnDynamic
local active, pending = {}, {}

local function key(src)
  local license = GetPlayerIdentifierByType(src, 'license')
  return license and ('last-location:' .. license) or nil
end

local function valid(c)
  if type(c) ~= 'table' then return false end
  for _, k in ipairs({'x','y','z','w'}) do
    if type(c[k]) ~= 'number' or c[k] ~= c[k] or math.abs(c[k]) > 20000 then return false end
  end
  return c.z > -100 and c.z < 2000 and (math.abs(c.x) + math.abs(c.y) > 1)
end

local function save(src)
  if not active[src] or GetPlayerRoutingBucket(src) ~= 0 then return end
  local ped = GetPlayerPed(src)
  if ped == 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 100 then return end
  -- Do not remember a seat in a moving aircraft/vehicle as an on-foot spawn.
  if GetVehiclePedIsIn(ped, false) ~= 0 then return end
  local p = GetEntityCoords(ped)
  local c = {x=p.x,y=p.y,z=p.z,w=GetEntityHeading(ped)}
  local k = key(src)
  if k and valid(c) then SetResourceKvp(k, json.encode(c)) end
end

function D.suspend(src)
  -- The ped may already be hidden/revived for the selector. Keep the last
  -- periodic gameplay sample rather than saving that temporary state.
  active[src], pending[src] = nil, nil
end
function D.approved(src) pending[src] = true end

RegisterNetEvent('flrp_spawn:spawned', function()
  local src = source
  if pending[src] then active[src], pending[src] = true, nil end
end)
AddEventHandler('playerDropped', function()
  local src = source
  save(src)
  active[src], pending[src] = nil, nil
end)
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then for src in pairs(active) do save(src) end end
end)
CreateThread(function()
  while true do
    Wait(15000)
    for src in pairs(active) do save(src) end
  end
end)

function D.last(src)
  local k = key(src)
  local raw = k and GetResourceKvpString(k)
  local ok, c = pcall(json.decode, raw or '')
  if ok and valid(c) then return c end
end

function D.aop()
  local ok, aop = pcall(function() return exports['nex-hud']:getAop() end)
  local areas = ok and type(aop)=='table' and aop.areas or nil
  if type(areas) ~= 'table' or #areas == 0 then return nil, 'Current AOP is unavailable.' end
  local names, target = {}, nil
  for _, code in ipairs(areas) do
    local entry = Config.AopSpawns[tostring(code):lower()]
    names[#names+1] = entry and entry.label or tostring(code)
    if not target and entry then target = entry end
  end
  if not target then return nil, 'No spawn configured for ' .. table.concat(names, ', ') .. '.' end
  return target.coords, table.concat(names, ' & ')
end

function D.resolve(src, id)
  if id == -1 then
    local coords, label = D.aop()
    return coords, coords and nil or label
  elseif id == -2 then
    local coords = D.last(src)
    return coords, coords and nil or 'No last location saved yet. Play on foot to save one.'
  end
end

function D.cards(src)
  local aop, label = D.aop()
  local last = D.last(src)
  return {
    {index=-1,name='Current AOP',category='quick',area=aop and label or 'Unavailable',
      desc=aop and 'Spawn at a public location in the current AOP. For multiple areas, uses the first configured area.' or label,
      image='../img/sandyshores.webp',allowed=aop~=nil,disabledReason=not aop and label or nil},
    {index=-2,name='Last Location',category='quick',area=last and 'Your previous position' or 'No saved location',
      desc='Return to your last saved on-foot location. Saved every 15 seconds during gameplay and retained across reconnects.',
      image='../img/legion.webp',allowed=last~=nil,disabledReason=not last and 'No last location saved yet.' or nil},
  }
end
