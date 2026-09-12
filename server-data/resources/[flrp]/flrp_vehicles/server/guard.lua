-- Enforce model policy for network vehicles created outside FLRP's menu too.
-- Never yield inside entityCreating; permission resolution is cached.
local names = {}
for name in pairs(FLRPVehiclePolicy.models) do names[GetHashKey(name)] = name end
for name in pairs(FLRPVehiclePolicy.blocked) do names[GetHashKey(name)] = name end

local function prohibited(entity)
  if GetEntityType(entity) ~= 2 then return false end
  local name = names[GetEntityModel(entity)]
  if not name then return false end
  if FLRPVehiclePolicy.blocked[name] then return true end
  local owner = NetworkGetEntityOwner(entity)
  -- Only gate player-created vehicles, not ownership migration of ambient traffic.
  if owner and owner > 0 and GetEntityPopulationType(entity) == 7 then
    local ok, allowed = pcall(FLRPV.Registry.CanSpawn, owner, name)
    return not ok or not allowed
  end
  return false
end

AddEventHandler('entityCreating', function(entity)
  if prohibited(entity) then CancelEvent() end
end)

-- Model/type may not be populated until creation completes on some artifacts.
AddEventHandler('entityCreated', function(entity)
  if prohibited(entity) then DeleteEntity(entity) end
end)
