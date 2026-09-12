# Florida map labels

Five neutral district labels on the pause map and minimap, placed over the existing oulsen_satmap satellite tiles and postals. No territory fills or blips are added.

Edit `config.lua` to move or rename districts. Coordinates are GTA world coordinates; the layout is a roleplay adaptation, not a geographically accurate Miami map. Del Perro/Pacific Bluffs is Miami Beach; the northern county is Broward.

A fixed 4096-square transparent canvas spans X -6000..6000 and Y -4000..8000. It is drawn once on resource startup, using white outlined text. One runtime texture and one DUI are kept until resource stop. Browser and scaleform loading have timeouts; the existing map continues if the labels fail to load.

Ensure after oulsen_satmap. Confirm placement, orientation and readability at both map zoom levels in FiveM; browser/Lua tests cannot validate GTA's final scaleform rendering.

## Credits and license

GPL-3.0 license included. FLRP implementation written September 12, 2026. The unchanged scaleform asset `FLRP_AREA_LABELS.gfx` was distributed as `MINIMAP_LOADER.gfx` by OffSey/Off-MapText at commit `698fd695bb4a79c00ae7baa3e5f7fddf61fbe7ce` (GPL-3.0): https://github.com/OffSey/Off-MapText . Its README credits https://github.com/manups4e/ScaleformUI for the GFX file. The texture-overlay calling convention follows that project's documented implementation. The Lua, HTML, and JavaScript implementation here are supplied in source form.
