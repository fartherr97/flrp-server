-- ==========================================================================
-- FLRP :: flrp_interact/config.lua — the "M" interaction menu
-- ==========================================================================
-- An SSRP-style interaction menu drawn in the native (vMenu) look. Default
-- keybind M (rebindable in Settings > Key Bindings > FiveM). Categories are
-- config-driven and gated by ACE server-side, so you add/rename entries here
-- without touching logic. Shared by client + server (shared_script).
-- ==========================================================================

FLRP_INTERACT = {}

FLRP_INTERACT.Key       = 'M'                    -- default keybind (players can rebind)
FLRP_INTERACT.Title     = 'FLRP'                 -- banner title
FLRP_INTERACT.Subtitle  = 'INTERACTION'          -- banner subtitle

-- Native-menu theme (RGBA 0-255). Kept close to the FLRP slate/cyan palette
-- but in the classic vMenu shape (dark rows, white selected row).
FLRP_INTERACT.Theme = {
  banner    = { 16, 22, 30, 255 },     -- header bar
  accent    = {  0, 191, 196, 255 },   -- FLRP cyan (title + accent line)
  subtitle  = {  9, 12, 17, 235 },     -- subtitle bar
  rowIdle   = {  0,  0,  0, 170 },     -- unselected row
  rowSel    = { 236, 240, 244, 255 },  -- selected row (light)
  textIdle  = { 236, 240, 244, 255 },  -- unselected text
  textSel   = {  12,  16,  22, 255 },  -- selected text (dark)
  textDim   = { 140, 150, 160, 255 },  -- disabled text
  desc      = {  9,  12,  17, 235 },   -- description box
  descText  = { 200, 210, 220, 255 },
}

-- ---- Advertisements ------------------------------------------------------
FLRP_INTERACT.Ads = {
  MaxLength      = 180,
  -- Civilian "business" advert -> broadcast to everyone.
  CivCooldown    = 120,                       -- seconds between civ ads per player
  CivLabel       = '📢 ADVERTISEMENT',
  CivColor       = { 46, 204, 113 },          -- green
  -- LEO department advisory -> broadcast to everyone, dept-branded.
  LeoCooldown    = 90,                        -- seconds between LEO ads per player
  LeoLabelSuffix = 'ADVISORY',                -- "<DEPT> ADVISORY"
  -- Per-department branding for LEO advisories (colour matches flrp_chat).
  Depts = {
    { ace = 'flrp.dept.bso', label = 'BSO', color = { 46, 139, 87 } },   -- green
    { ace = 'flrp.dept.fhp', label = 'FHP', color = { 184, 134, 11 } },  -- tan
    { ace = 'flrp.dept.mpd', label = 'MPD', color = { 31, 111, 235 } },  -- blue
  },
}

-- ---- Toolboxes -----------------------------------------------------------
-- Each entry is an action item. Supported `action` types:
--   emote        -> play a built-in animation (see client/main.lua Emotes)
--   cancel       -> ClearPedTasks (stop current animation)
--   command      -> ExecuteCommand(arg) locally (route to an existing command)
--   client_event -> TriggerEvent(arg, ...) on the client
--   server_event -> TriggerServerEvent(arg, ...)
-- `desc` shows in the description box. Add your own rows freely.

-- Civilian toolbox — visible to everyone. `emote` uses a built-in anim (see
-- client Emotes table); `scenario` plays a GTA scenario in place.
FLRP_INTERACT.CivilianToolbox = {
  { label = 'Hands Up',       desc = 'Put your hands above your head.',     action = 'emote',    arg = 'handsup' },
  { label = 'Surrender',      desc = 'Kneel with your hands behind you.',   action = 'emote',    arg = 'surrender' },
  { label = 'Sit Down',       desc = 'Sit on the ground where you stand.',  action = 'scenario', arg = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER' },
  { label = 'Lean',           desc = 'Lean back against a wall.',           action = 'scenario', arg = 'WORLD_HUMAN_LEANING' },
  { label = 'Smoke',          desc = 'Smoke a cigarette.',                  action = 'scenario', arg = 'WORLD_HUMAN_SMOKING' },
  { label = 'Clipboard',      desc = 'Hold a clipboard and take notes.',    action = 'scenario', arg = 'WORLD_HUMAN_CLIPBOARD' },
  { label = 'Guard Stance',   desc = 'Stand with your arms crossed.',       action = 'scenario', arg = 'WORLD_HUMAN_GUARD_STAND' },
  { label = 'Stop Animation', desc = 'Cancel the current animation.',       action = 'cancel' },
  -- Wire your own /e emote menu here, e.g.
  -- { label = 'Emote Menu',  desc = 'Open the emote menu.',                action = 'command', arg = 'emotemenu' },
}

-- LEO toolbox — visible to on-duty / sworn law enforcement (flrp.leo).
-- Cuff/Drag/Seat are provided by flrp_leotools (server-authoritative, gated by
-- flrp.leo); they act on the nearest player / vehicle.
FLRP_INTERACT.LeoToolbox = {
  { label = 'Cuff / Uncuff',      desc = 'Cuff or uncuff the nearest person.',            action = 'client_event', arg = 'flrp_leotools:doCuff' },
  { label = 'Escort (Drag)',      desc = 'Grab/release a cuffed person to walk them.',     action = 'client_event', arg = 'flrp_leotools:doDrag' },
  { label = 'Put in Vehicle',     desc = 'Seat the nearest person in a nearby vehicle.',   action = 'client_event', arg = 'flrp_leotools:doSeat' },
  { label = 'Remove from Vehicle',desc = 'Pull the nearest person out of a vehicle.',      action = 'client_event', arg = 'flrp_leotools:doUnseat' },
  { label = 'Duty Menu',          desc = 'Open the on-duty menu (callsign, loadout).',     action = 'command',      arg = 'duty' },
  { label = 'Stop Animation',     desc = 'Cancel the current animation.',                  action = 'cancel' },
  -- Add more department utilities here as their scripts are installed, e.g.
  -- { label = 'Spike Strip',  desc = 'Deploy a spike strip.', action = 'client_event', arg = 'flrp_spikes:deploy' },
}

-- ---- Donator vehicles ----------------------------------------------------
-- Donator spawns are pulled live from the flrp_vehicles registry: any enabled
-- vehicle in one of these categories that the player is permitted to spawn
-- (see flrp_vehicles / vehicles.cfg) appears here. No hard-coded list — add
-- vehicles to the registry with category 'donator' and they show up.
FLRP_INTERACT.DonatorVehicleCategories = { 'donator', 'donor', 'vip' }
FLRP_INTERACT.DonatorAce = 'flrp.donator'        -- gate for the category heading
