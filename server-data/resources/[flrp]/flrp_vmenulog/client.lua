-- ==========================================================================
-- FLRP :: flrp_vmenulog/client.lua — detect vMenu "Fix Vehicle" repairs
-- ==========================================================================
-- vMenu's Fix Vehicle is a client-only native call with no event to hook, so
-- we sample the driver's vehicle health and treat an instant jump to near-full
-- (engine or body) as a repair. Reports it once (debounced) to the server.
-- ==========================================================================

local cfg = FLRP_VMENULOG.Repair or {}

if cfg.Enabled ~= false then
  CreateThread(function()
    local prevEngine, prevBody = -1.0, -1.0
    local lastLog = 0
    local poll     = cfg.PollMs or 350
    local jumpMin  = cfg.JumpMin or 120.0
    local fullAbove = cfg.FullAbove or 950.0
    local cooldown = cfg.Cooldown or 4000

    while true do
      Wait(poll)
      local ped = PlayerPedId()
      local veh = GetVehiclePedIsIn(ped, false)
      -- only the driver, so passengers don't double-log a repair
      if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        local eng  = GetVehicleEngineHealth(veh)
        local body = GetVehicleBodyHealth(veh)
        if prevEngine >= 0 then
          local jumped = (eng - prevEngine) >= jumpMin or (body - prevBody) >= jumpMin
          local full   = eng >= fullAbove and body >= fullAbove
          local now    = GetGameTimer()
          if jumped and full and (now - lastLog) > cooldown then
            lastLog = now
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
            TriggerServerEvent('flrp_vmenulog:repair', model)
          end
        end
        prevEngine, prevBody = eng, body
      else
        prevEngine, prevBody = -1.0, -1.0
      end
    end
  end)
end
