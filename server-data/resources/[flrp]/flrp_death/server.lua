-- ==========================================================================
-- FLRP :: flrp_death/server.lua — authoritative dead state + gating
-- ==========================================================================
-- Tracks who is down and since when, and enforces the respawn/revive locks:
--   respawn : staff instantly; everyone else after WaitSeconds.
--   revive  : staff can revive anyone anytime; a non-staff reviver must wait
--             out the target's WaitSeconds.
-- ==========================================================================

local dead = {}  -- [src] = { at = os.time(), staff = bool }

local function isStaff(src) return IsPlayerAceAllowed(src, FLRP_DEATH.BypassAce) end
local function name(src) return GetPlayerName(src) or ('Player ' .. src) end
local function toast(dst, body, kind)
  TriggerClientEvent('flrp_notify:toast', dst, { title = 'Medical', body = body, kind = kind or 'info' })
end

local function within(a, b, max)
  local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
  if pa == 0 or pb == 0 then return false end
  return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= max
end

-- ---- death ----------------------------------------------------------------
RegisterNetEvent('flrp_death:died', function()
  local src = source
  local staff = isStaff(src)
  dead[src] = { at = os.time(), staff = staff }
  TriggerClientEvent('flrp_death:state', src, { staff = staff, wait = FLRP_DEATH.WaitSeconds })
end)

-- ---- self respawn (player pressed the key) --------------------------------
RegisterNetEvent('flrp_death:tryRespawn', function()
  local src = source
  local d = dead[src]; if not d then return end
  local ok = d.staff or (os.time() - d.at) >= FLRP_DEATH.WaitSeconds
  if not ok then return end                       -- client already gates; double-check
  dead[src] = nil
  TriggerClientEvent('flrp_death:respawnApproved', src)
end)

-- ---- revive (reviver -> nearest downed target) ----------------------------
RegisterNetEvent('flrp_death:revive', function(target)
  local src = source
  target = tonumber(target)
  if not target or not GetPlayerName(target) then return end
  if not dead[target] then return toast(src, 'They are not down.', 'error') end
  if not within(src, target, FLRP_DEATH.ReviveReach + 1.5) then
    return toast(src, 'Too far away to revive them.', 'error')
  end
  local elapsed = os.time() - dead[target].at
  if not isStaff(src) and elapsed < FLRP_DEATH.WaitSeconds then
    return toast(src, ('They cannot be revived for another %ds.'):format(FLRP_DEATH.WaitSeconds - elapsed), 'error')
  end
  dead[target] = nil
  TriggerClientEvent('flrp_death:revived', target, src)
  toast(src, 'You revived ' .. name(target) .. '.', 'ok')
end)

AddEventHandler('playerDropped', function()
  if dead[source] then dead[source] = nil end
end)
