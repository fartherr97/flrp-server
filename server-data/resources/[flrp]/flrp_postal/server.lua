-- ==========================================================================
-- FLRP :: flrp_postal/server.lua — serves the postal dataset to clients
-- ==========================================================================
-- Reads a postal-code -> coordinate file (from whichever mapping resource
-- provides one) and hands the RAW json to each client on request. The client
-- parses it once and answers /p <postal> by dropping a GPS waypoint. Reading
-- server-side means we don't care whether the source resource ships the file
-- to clients — the server always has it on disk.
--
-- Source priority: the satellite map's own postal file first (its codes match
-- what players see on the map), then nex-hud's as a fallback.
-- ==========================================================================

local SOURCES = {
  { res = 'oulsen_satmap', file = 'oulsen_satmap_postals.json' },
  { res = 'nex-hud',       file = 'assets/postals.json' },
}

local postalRaw, postalSrc

local function pick()
  for _, s in ipairs(SOURCES) do
    local raw = LoadResourceFile(s.res, s.file)
    if raw and #raw > 2 then
      local ok, data = pcall(json.decode, raw)
      if ok and type(data) == 'table' and next(data) ~= nil then
        return raw, s.res
      end
    end
  end
  return nil, nil
end

CreateThread(function()
  -- Give content resources a moment to be present after a fresh boot.
  Wait(2500)
  postalRaw, postalSrc = pick()
  if postalRaw then
    print(('[flrp_postal] postal data loaded from "%s" (%d bytes)'):format(postalSrc, #postalRaw))
  else
    print('[flrp_postal] WARNING: no postal file found (looked for oulsen_satmap / nex-hud) — /p will be unavailable')
  end
end)

RegisterNetEvent('flrp_postal:request', function()
  local src = source
  if not postalRaw then postalRaw, postalSrc = pick() end   -- retry lazily
  TriggerClientEvent('flrp_postal:data', src, postalRaw or '')
end)
