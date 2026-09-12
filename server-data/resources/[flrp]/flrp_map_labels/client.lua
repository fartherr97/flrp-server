-- Transparent atlas overlay; never takes NUI focus or changes map tiles/blips.
local resource = GetCurrentResourceName()
local dui, overlay
local ready, rendered, stopping = false, false, false
RegisterNUICallback('ready', function(_, cb) ready = true; cb({ok=true}) end)
RegisterNUICallback('rendered', function(_, cb) rendered = true; cb({ok=true}) end)

local function waitFor(predicate, timeout)
    local started = GetGameTimer()
    while not stopping and not predicate() and GetGameTimer() - started < timeout do Wait(25) end
    return not stopping and predicate()
end

local function cleanup()
    if overlay then
        CallMinimapScaleformFunction(overlay, 'REM_OVERLAY')
        ScaleformMovieMethodAddParamInt(0)
        EndScaleformMovieMethod()
        SetMinimapOverlayDisplay(overlay, 0.0, 0.0, 100.0, 100.0, 0.0)
    end
    if dui then DestroyDui(dui); dui = nil end
end

CreateThread(function()
    local size = Config.TextureSize
    dui = CreateDui(('https://cfx-nui-%s/html/index.html?resource=%s'):format(resource, resource), size, size)
    if not waitFor(function() return IsDuiAvailable(dui) and ready end, 10000) then
        print('[flrp_map_labels] Browser did not initialize; labels disabled.'); cleanup(); return
    end
    SendDuiMessage(dui, json.encode({ action='render', size=size, bounds=Config.Bounds, labels=Config.Labels, style=Config.Style }))
    if not waitFor(function() return rendered end, 5000) then
        print('[flrp_map_labels] Atlas did not render; labels disabled.'); cleanup(); return
    end
    local txdName, textureName = 'flrp_area_labels_txd', 'flrp_area_labels_texture'
    local txd = CreateRuntimeTxd(txdName)
    CreateRuntimeTextureFromDuiHandle(txd, textureName, GetDuiHandle(dui))
    overlay = AddMinimapOverlay('FLRP_AREA_LABELS.gfx')
    if not waitFor(function() return HasMinimapOverlayLoaded(overlay) end, 10000) then
        print('[flrp_map_labels] Scaleform did not load; labels disabled.'); cleanup(); return
    end
    SetMinimapOverlayDisplay(overlay, 0.0, 0.0, 100.0, 100.0, 100.0)
    local b = Config.Bounds
    CallMinimapScaleformFunction(overlay, 'ADD_SCALED_OVERLAY')
    ScaleformMovieMethodAddParamTextureNameString(txdName)
    ScaleformMovieMethodAddParamTextureNameString(textureName)
    ScaleformMovieMethodAddParamFloat((b.minX + b.maxX) / 2)
    ScaleformMovieMethodAddParamFloat((b.minY + b.maxY) / 2)
    ScaleformMovieMethodAddParamFloat(0.0)
    ScaleformMovieMethodAddParamFloat((b.maxX - b.minX) / size * 100)
    ScaleformMovieMethodAddParamFloat((b.maxY - b.minY) / size * 100)
    ScaleformMovieMethodAddParamInt(100)
    ScaleformMovieMethodAddParamBool(true)
    EndScaleformMovieMethod()
end)

AddEventHandler('onClientResourceStop', function(name)
    if name ~= resource then return end
    stopping = true
    cleanup()
end)
