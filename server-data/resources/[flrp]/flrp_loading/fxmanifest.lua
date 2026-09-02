-- ==========================================================================
-- FLRP :: flrp_loading — custom South Miami loading screen
-- ==========================================================================
-- A self-contained loading screen (Art Deco Miami twilight) shown while players
-- connect. Only ONE loadscreen resource may be active — nex-loading must be
-- disabled (it is not `ensure`d) when this is enabled. See config/resources.cfg.
--
-- The page loads the FLRP logo + Google Fonts from the internet (the FiveM
-- loading-screen CEF browser has network access) and falls back gracefully if
-- either is unavailable. It reads FiveM's loadProgress events for the real
-- progress bar, with a CSS fallback animation if none arrive.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_loading'
author 'Florida Roleplay (FLRP)'
description 'FLRP custom loading screen — South Miami / Art Deco twilight'
version '1.0.0'

loadscreen 'index.html'

files {
  'index.html',
  'bgm.ogg',   -- background music. Drop a royalty-free .ogg here named bgm.ogg.
               -- Until the file exists FiveM logs one harmless "file not found"
               -- warning and the loader is silent. USE ROYALTY-FREE / LICENSED
               -- audio only — copyrighted songs can get the server DMCA'd.
}
