-- ==========================================================================
-- FLRP :: flrp_gunstores/shared/config.lua — store locations
-- ==========================================================================
-- Store LOCATIONS are configurable world coordinates (no MLO/map assets are
-- required). Edit / add stores here; the server validates that a purchasing
-- player is actually near the store they claim to use. Prices and the weapon
-- catalog are NOT here — they live in the weapon registry (DB), which is the
-- authoritative source. See docs/WEAPONS.md and docs/ASSET_IMPORT.md.
--
-- The entries below are DEV PLACEHOLDER locations (Ammu-Nation-ish coords) so
-- the flow can be tested before final map/MLO work. Replace/extend freely.
-- ==========================================================================

FLRPG = FLRPG or {}
FLRPG.Config = {}

-- Interaction radius (metres) around a store marker.
FLRPG.Config.InteractRadius = 2.5

-- Server-side proximity tolerance (metres). A purchase is rejected if the
-- player is further than this from the claimed store (anti-exploit).
FLRPG.Config.ServerProximityTolerance = 6.0

-- Show a floating marker + prompt at each store.
FLRPG.Config.ShowMarkers = true

-- Stores: id must be stable + unique. coords are world XYZ.
-- NOTE: DEV PLACEHOLDER coordinates — confirm/replace during map work.
FLRPG.Config.Stores = {
  {
    id = 'dev_ammu_1',
    label = '[DEV] Gun Store 1',
    coords = { x = 21.7, y = -1106.7, z = 29.8 },   -- DEV PLACEHOLDER
    blip = { enabled = true, sprite = 110, color = 1, scale = 0.8 },
  },
  {
    id = 'dev_ammu_2',
    label = '[DEV] Gun Store 2',
    coords = { x = 810.2, y = -2157.6, z = 29.6 },  -- DEV PLACEHOLDER
    blip = { enabled = true, sprite = 110, color = 1, scale = 0.8 },
  },
}

function FLRPG.Config.GetStore(id)
  for _, s in ipairs(FLRPG.Config.Stores) do
    if s.id == id then return s end
  end
  return nil
end
