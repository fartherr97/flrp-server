-- ==========================================================================
-- FLRP :: flrp_gunstores/server/main.lua — net event wiring
-- ==========================================================================

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRP.Logger.Info('gunstore', 'flrp_gunstores ready')
end)

-- Client requests the store catalog (display-safe; prices are informational,
-- re-validated at purchase). We build it from the authoritative registry.
RegisterNetEvent('flrp_gunstores:requestCatalog', function()
  local source = tonumber(source)
  local catalog = exports.flrp_weapons:GetStoreCatalog()
  -- Annotate each item with whether THIS player is eligible (so the UI can
  -- show/lock items). Eligibility is still re-checked authoritatively on buy.
  for _, item in ipairs(catalog) do
    local eligible = exports.flrp_permissions:HasPermission(source, 'weapon.gunstore.purchase')
    if eligible and item.certRequired and item.certRequired ~= '' then
      eligible = exports.flrp_permissions:IsInGroup(source, item.certRequired)
    end
    if eligible and item.requiredPermission and item.requiredPermission ~= '' then
      eligible = exports.flrp_permissions:HasPermission(source, item.requiredPermission)
    end
    item.eligible = eligible and true or false
    item.owned = exports.flrp_weapons:OwnsWeapon(source, item.weaponName)
  end
  TriggerClientEvent('flrp_gunstores:catalog', source, catalog,
    exports.flrp_economy:GetBalance(source))
end)

-- Purchase request. Client sends weaponName + storeId only; server decides all.
RegisterNetEvent('flrp_gunstores:purchase', function(weaponName, storeId)
  local source = tonumber(source)
  local ok, res = FLRPG.Purchase.Attempt(source, weaponName, storeId)
  TriggerClientEvent('flrp_gunstores:purchaseResult', source, ok, res)
end)
