# Florida plates

Artwork: badger.dev / Midatlantic Mods, Florida Game License Plates 1.0.0.
Source: https://www.lcpdfr.com/downloads/gta5mods/misc/51063-florida-game-license-plates/
Original ZIP SHA256: 9edd4e5a84053054fd8ab414f98dcdf1994ee6a570e6513d7ae7dfa8d9fb3a84
Creator terms: https://docs.google.com/document/d/1n10lttpWyhtF-2d_qJqCxqrXzaNUocfhGVCS6F3bHok/edit
Credit the creator; do not sell these assets or claim authorship.

Slots: 0 City, 1 FWC, 2 Sheriff, 3 civilian Sunshine State, 4 County, 5 FHP.
Ambient traffic is changed to slot 3 within 750ms of observation by its owning
client. Player-occupied, mission and permanent vehicles are excluded. Plate
numbers are never changed. Player-selected plates remain available.

Only 14 plate/font textures are extracted into a uniquely named dictionary.
No full vehshare or carcols override is installed. The original pack's custom
font colors and character placement require its client-side carcols.ymt;
server clients retain their existing font colors/placement. In-game visual
verification is required, particularly the FHP black background.

Start with `ensure flrp_florida_plates`. Stop removes the texture replacements;
already-converted ambient vehicles retain the civilian plate index.
Radar images 0..5 are copied unchanged; additional DLC plate images are retained.
