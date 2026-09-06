-- ==========================================================================
-- FLRP :: flrp_vmenulog/server.lua — time/weather + repair -> Discord
-- ==========================================================================

local function pname(src) return GetPlayerName(src) or ('Player ' .. tostring(src)) end

-- ---- Weather (vMenu synced) ----------------------------------------------
AddEventHandler(FLRP_VMENULOG.WeatherEvent, function(newWeather, blackout)
  local src = source
  if not src or src <= 0 then return end
  if FLRP_VMENULOG.Debug then
    print(('[flrp_vmenulog] weather by [%s] -> %s (blackout=%s)'):format(src, tostring(newWeather), tostring(blackout)))
  end
  pcall(function()
    exports.flrp_logs:Send('timeweather', {
      player = src, title = 'WEATHER CHANGE',
      description = ('**%s** set the weather to **%s**%s.')
        :format(pname(src), tostring(newWeather), blackout and ' — blackout on' or ''),
    })
  end)
end)

-- ---- Time (vMenu synced) --------------------------------------------------
AddEventHandler(FLRP_VMENULOG.TimeEvent, function(hours, minutes, freeze)
  local src = source
  if not src or src <= 0 then return end
  if FLRP_VMENULOG.Debug then
    print(('[flrp_vmenulog] time by [%s] -> %s:%s (freeze=%s)'):format(src, tostring(hours), tostring(minutes), tostring(freeze)))
  end
  pcall(function()
    exports.flrp_logs:Send('timeweather', {
      player = src, title = 'TIME CHANGE',
      description = ('**%s** set the time to **%02d:%02d**%s.')
        :format(pname(src), tonumber(hours) or 0, tonumber(minutes) or 0, freeze and ' — frozen' or ''),
    })
  end)
end)

-- ---- Repair (detected client-side) ---------------------------------------
RegisterNetEvent('flrp_vmenulog:repair', function(model)
  local src = source
  pcall(function()
    exports.flrp_logs:Send('repair', {
      player = src,
      description = ('**%s** repaired their vehicle%s.')
        :format(pname(src), (model and model ~= '') and (' — ' .. tostring(model)) or ''),
    })
  end)
end)
