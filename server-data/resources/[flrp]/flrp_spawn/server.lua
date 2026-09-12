-- ==========================================================================
-- FLRP :: flrp_spawn/server.lua — Discord-role-gated spawn approval
-- ==========================================================================
-- The gate is enforced HERE, not on the client. A category (or point) lists
-- Discord role IDs (config.lua) and the player must hold at least one. Roles
-- come from flrp_permissions' cache of what flrp_access read at the
-- connection gate — so they're known before the client even loads — with a
-- live Discord lookup through flrp_access as the fallback if that cache is
-- gone (resource restarted mid-session).
--
-- Deliberately NOT ACE-based: no principal timing, no staff bypass. To let a
-- group in, add its role ID to Config.LeoRoles (or the convar override).
-- ==========================================================================

local catById = {}
for _, c in ipairs(Config.Categories) do catById[c.id] = c end

-- Boot-time override: `set flrp_spawn_leo_roles "id,id,id"` in secrets.cfg.
do
  local raw = GetConvar('flrp_spawn_leo_roles', '')
  if raw ~= '' then
    local list = {}
    for id in raw:gmatch('[^,%s]+') do list[#list + 1] = id end
    if #list > 0 then
      Config.LeoRoles = list
      if catById.leo then catById.leo.roles = list end
      print(('[flrp_spawn] LEO roles overridden by flrp_spawn_leo_roles (%d ids)'):format(#list))
    end
  end
end

-- Which Discord roles must a player hold for this point? nil = open to all.
local function requiredRoles(p)
  if p.roles then return p.roles end
  local cat = catById[p.category or 'civ']
  return cat and cat.roles or nil
end

-- Set of role ids this player holds. Cache first; live Discord read second.
local function heldRoles(src)
  local ok, ids = pcall(function() return exports.flrp_permissions:GetDiscordRoleIds(src) end)
  if not ok or type(ids) ~= 'table' then
    local ok2, live = pcall(function() return exports.flrp_access:GetDiscordRoleIds(src) end)
    ids = (ok2 and type(live) == 'table') and live or {}
  end
  local set = {}
  for _, id in ipairs(ids) do set[tostring(id)] = true end
  return set
end

local function canUse(held, p)
  local need = requiredRoles(p)
  if not need or #need == 0 then return true end
  for _, id in ipairs(need) do
    if held[tostring(id)] then return true end
  end
  return false
end

-- Which points may this player use?
RegisterNetEvent('flrp_spawn:requestPoints', function()
  local src = source
  FLRPSpawnDynamic.suspend(src)
  local held = heldRoles(src)
  local allowed = {}
  for i, p in ipairs(Config.Points) do allowed[i] = canUse(held, p) end
  TriggerClientEvent('flrp_spawn:points', src, allowed, FLRPSpawnDynamic.cards(src))
end)

-- Approve (or deny) a chosen point after re-checking server-side.
RegisterNetEvent('flrp_spawn:selectPoint', function(index)
  local src = source
  index = tonumber(index)
  if index == -1 or index == -2 then
    local coords, reason = FLRPSpawnDynamic.resolve(src, index)
    if not coords then TriggerClientEvent('flrp_spawn:denied', src, reason); return end
    FLRPSpawnDynamic.approved(src)
    TriggerClientEvent('flrp_spawn:approved', src, index, coords)
    return
  end
  local p = index and Config.Points[index]
  if not p then return end
  if not canUse(heldRoles(src), p) then
    TriggerClientEvent('flrp_spawn:denied', src)
    return
  end
  FLRPSpawnDynamic.approved(src)
  TriggerClientEvent('flrp_spawn:approved', src, index)
end)

-- Console diagnostic: flrp_spawn_check <serverId>
-- Prints the role ids the player holds, what each gated category wants, and
-- the verdict — so "why is the LEO lane locked for X?" is one command.
RegisterCommand('flrp_spawn_check', function(source, args)
  if source ~= 0 then return end
  local target = tonumber(args[1] or '')
  if not target or not GetPlayerName(target) then
    print('[flrp_spawn_check] usage: flrp_spawn_check <serverId>  (player must be connected)')
    return
  end
  local held = heldRoles(target)
  local list = {}
  for id in pairs(held) do list[#list + 1] = id end
  table.sort(list)
  print(('== flrp_spawn_check: [%s] %s =='):format(target, GetPlayerName(target)))
  print(('holds %d discord role ids: %s'):format(#list, #list > 0 and table.concat(list, ', ') or '(none)'))
  for _, c in ipairs(Config.Categories) do
    if c.roles and #c.roles > 0 then
      local hit
      for _, id in ipairs(c.roles) do
        if held[tostring(id)] then hit = id; break end
      end
      print(('%-5s needs one of: %s -> %s'):format(c.id, table.concat(c.roles, ', '),
        hit and ('ALLOWED (has ' .. hit .. ')') or 'LOCKED'))
    else
      print(('%-5s open to everyone'):format(c.id))
    end
  end
end, true)
