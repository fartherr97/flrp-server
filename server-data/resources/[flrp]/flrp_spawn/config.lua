-- ==========================================================================
-- FLRP :: flrp_spawn/config.lua — spawn selector points + menu content
-- ==========================================================================
-- Points are grouped into CATEGORIES (LEO / Civilian / Fire-EMS) in the NUI.
-- Each point: name, area, category, coords vector4(x,y,z,heading), `desc`
-- (Information box) and `image` (card art, from img/).
--
-- Gating is by DISCORD ROLE, checked server-side against the roles flrp_access
-- read at connect: a category (or a single point) lists `roles = {...}` and the
-- player must hold AT LEAST ONE of them. No ACE, no staff bypass — to let a
-- group in, add its role ID to the list. Ungated categories are open to all.
-- ==========================================================================
Config = Config or {}

-- ---- LEO access roles ----------------------------------------------------
-- Main-guild Discord role IDs. Holding ANY ONE of these unlocks the LEO lane.
-- Override without a deploy: `set flrp_spawn_leo_roles "id1,id2,id3"` in
-- secrets.cfg (comma-separated) replaces this list at boot (server-side).
Config.LeoRoles = {
  '1534380752207220736',
  '1534380748247666796',
  '1534911171319042159',
}

-- ---- Branding / header ---------------------------------------------------
Config.Header = {
  title    = 'FLRP',
  subtitle = 'SPAWN SELECTOR',
  blurb    = 'Same state, different stories. Pick a lane, then a location — the world reshapes around you.',
  tagline  = 'Florida Roleplay',
  welcome  = 'Welcome to FLRP',
  welcomeA = 'Active Community, ',
  welcomeB = 'Hybrid vMenu',
  flourish = 'Miami',
}

-- ---- Categories ----------------------------------------------------------
-- accent: cyan | magenta | ember   icon: shield | people | cross
-- roles (optional): a category is locked unless the player holds at least one
-- of these Discord role IDs. Individual points can carry their own `roles` too.
Config.Categories = {
  { id = 'leo',  label = 'LEO Spawn Points',       tag = 'Serve · Protect · Florida', accent = 'cyan',    icon = 'shield',
    roles = Config.LeoRoles,
    blurb = 'Sworn law enforcement only. Report on duty at your agency, gear up and hit the road.' },
  { id = 'civ',  label = 'Civilian Spawn Points',  tag = 'Live · Work · Explore',     accent = 'magenta', icon = 'people',
    blurb = 'Same state, different stories. Drop into the city, the suburbs or the coast and write your own.' },
  { id = 'fire', label = 'Fire / EMS Spawn Points', tag = 'Care · Respond · Save Lives', accent = 'ember', icon = 'cross',
    blurb = 'Fire Rescue and EMS. Post up at your station and run calls across the county.' },
}

-- ---- Points --------------------------------------------------------------
Config.Points = {
  -- Civilian (open to everyone)
  { name = 'Downtown Miami',    area = 'Miami-Dade',      category = 'civ', image = '../img/legion.webp',     desc = 'Bayfront core — banks, high-rises and the busiest civilian hub.',        coords = vector4(197.94, -932.4, 30.69, 320.0) },
  { name = 'South Beach',       area = 'Miami Beach',     category = 'civ', image = '../img/delperro.jpg',    desc = 'Ocean Drive — the boardwalk, the pier and the nightlife strip.',          coords = vector4(-1341.27, -1298.66, 4.84, 292.0) },
  { name = 'Coral Gables',      area = 'Miami-Dade',      category = 'civ', image = '../img/vinewood.webp',   desc = 'Tree-lined estates, Miracle Mile and old-money mansions.',               coords = vector4(436.64, 218.38, 103.62, 160.0) },
  { name = 'Coconut Grove',     area = 'Miami-Dade',      category = 'civ', image = '../img/mirrorpark.webp', desc = 'Leafy bayside neighbourhood — marinas, cafés and quiet streets.',         coords = vector4(1130.21, -645.9, 56.58, 272.0) },
  { name = 'Jackson Memorial',  area = 'Miami-Dade',      category = 'civ', image = '../img/pillbox.jpg',     desc = 'Civic Center medical district beside the county hospital.',              coords = vector4(298.98, -584.45, 43.26, 70.0) },
  { name = 'Miami International',area = 'Miami-Dade',      category = 'civ', image = '../img/airport.webp',    desc = 'MIA — air ops, cargo and the Dolphin Expressway.',                       coords = vector4(-1037.74, -2738.04, 20.17, 330.0) },
  { name = 'Deerfield Beach',   area = 'Broward County',  category = 'civ', image = '../img/paleto.jpg',      desc = 'Far-north coastal town — the pier, the beach and the bank.',             coords = vector4(-134.20, 6212.20, 31.21, 47.09) },
  { name = 'Davie',             area = 'Broward County',  category = 'civ', image = '../img/sandyshores.webp',desc = 'Western Broward — ranches, the rodeo grounds and open road.',            coords = vector4(1884.41, 3714.45, 32.93, 210.0) },
  { name = 'Homestead',         area = 'South Dade',      category = 'civ', image = '../img/grapeseed.webp',  desc = 'Quiet Redland farming community — nurseries and packing houses.',        coords = vector4(1654.72, 4825.46, 42.08, 280.0) },

  -- LEO (gated by Config.LeoRoles through the 'leo' category)
  { name = 'Miami PD Headquarters', area = 'Miami-Dade · MPD',  category = 'leo', image = '../img/missionrow.webp',  desc = 'City police HQ — patrol briefing, CID and the motor pool.',            coords = vector4(440.83, -984.53, 22.85, 268.2) },
  { name = 'BSO Davie District',    area = 'Broward County · BSO', category = 'leo', image = '../img/sandyshores.webp', desc = "Broward Sheriff's Office district station covering west Broward.",     coords = vector4(1850.71, 3700.96, 33.76, 291.4) },
  { name = 'FHP Troop E',           area = 'Florida Turnpike · FHP', category = 'leo', image = '../img/grapeseed.webp', desc = 'Highway Patrol Troop E — interstate interdiction and CVE.',            coords = vector4(2821.90, 4763.21, 47.37, 78.8) },

  -- Fire / EMS  (EXAMPLE stations — replace coords with real ones via /coords)
  { name = 'Miami Fire Rescue HQ',  area = 'Miami-Dade · MFR', category = 'fire', image = '../img/pillbox.jpg',     desc = 'EXAMPLE — replace coords. Rescue 1, the training tower and the EOC.',   coords = vector4(298.98, -584.45, 43.26, 70.0) },
  { name = 'Station 4 — South Beach', area = 'Miami Beach',    category = 'fire', image = '../img/delperro.jpg',    desc = 'EXAMPLE — replace coords. Beachfront ALS engine and rescue.',           coords = vector4(-1341.27, -1298.66, 4.84, 292.0) },
  { name = 'BSO Fire — Davie',      area = 'Broward County',   category = 'fire', image = '../img/sandyshores.webp',desc = 'EXAMPLE — replace coords. County ALS coverage for west Broward.',      coords = vector4(1884.41, 3714.45, 32.93, 210.0) },
}

-- ---- Menu pages (edit freely — no rebuild needed) ------------------------
Config.Menu = {
  updates = {
    note = 'Live feed — mirrors the #updates Discord channel where Gitea posts every commit.',
    items = {
      { tag = 'New',      color = '#33e1ff', title = 'Spawn selector — reimagined',   hash = 'a1b2c3d',       by = 'Dev Team',   when = 'just now',  body = 'Brand-new Miami spawn screen: LEO / Civilian / Fire-EMS lanes, live location previews, role-gated access and a recoloring skyline.' },
      { tag = 'Added',    color = '#ff2e95', title = 'Sonoran Radio is live',          hash = '6e8f3d8',       by = 'Dev Team',   when = 'today',     body = 'In-game radio is back — channels, tones and the mobile repeater. Report on duty and get on comms.' },
      { tag = 'Added',    color = '#33e1ff', title = 'Two-way Discord chat bridge',    hash = 'c675e82',       by = 'Dev Team',   when = 'today',     body = 'In-game chat streams to Discord and back as [Discord] tags. New /ooc, /gooc, /me and /gme commands.' },
      { tag = 'Improved', color = '#ff7a3a', title = 'Report menu rebuilt',            hash = 'd549e6b',       by = 'Staff Team', when = 'yesterday', body = 'Fresh report UI with claims, live threads, analytics and a nearest-players attach.' },
      { tag = 'Fixed',    color = '#59d98a', title = 'MPD Miami fleet restored',       hash = 'MiamiMegapack', by = 'Dev Team',   when = 'yesterday', body = 'PD1–PD7 back in service after a pack regression, plus new slicktop and legacy interceptors.' },
    },
  },
  about = {
    title = 'A higher standard',
    paragraphs = {
      "Here at Florida Roleplay we've been playing FiveM for almost ten years — long enough to know exactly what a great server feels like, and exactly what we were tired of missing.",
      "FLRP is our answer: a Miami-based world built for serious roleplay without the gatekeeping. Active community, hybrid vMenu, custom scripts and departments that actually run. Good people, great stories — and plenty of room for yours.",
    },
    stats = {
      { n = '10 Yrs',      l = 'Experience' },
      { n = 'Miami',       l = 'Based' },
      { n = 'BSO·FHP·MPD',  l = 'Departments' },
      { n = 'Est. 2026',   l = 'Florida Roleplay' },
    },
  },
  leadership = {
    subtitle = 'The people keeping the standard higher.',
    groups = {
      { label = 'Ownership',    people = { { n = 'Jordan', t = 'Owner' }, { n = 'Mike', t = 'Owner' }, { n = 'Johnson', t = 'Owner' } } },
      { label = 'Directorship', people = { { n = 'Juan', t = 'Executive Director' } } },
    },
  },
}

-- Banner logo (top-left of the rail). Bundled locally.
Config.LogoUrl = '../img/flrp-logo.png'

-- ---- Respawn behaviour ---------------------------------------------------
Config.RespawnToSelector = true
Config.RespawnDelay = 3000
