# FLRP department clothing

The configuration starts fhp-eup, bso-eup, mpd-eup and flrp-vests from flrp-eup. Download Git LFS binaries before startup. Do not also start the original JA Designs or Endeavor resources using the same collections.

In vMenu, load an MP male/female character and open Player Appearance > Customize. The clothing uses numeric variations. /flrpeup prints the live global drawable ranges for each department and flags unloaded collections; it does not equip clothing. Endeavor uses Body Armor (textures 0 FHP, 1 BSO, 2 Miami Police) and Bags/Parachutes (optional gear). Its supplied model is male only.

Optional fitting helpers: /flrpfhp top 0 0, /bso top 0 0, /flrpmpd top 0 0; replace top with pants, vest, bag or hat as supported. The list action only lists. The restore action restores the helper snapshot. /fhp is deliberately not registered because Skybox uses it for unit chat. Close vMenu while applying commands, fit compatible arms/undershirt, then save through Player Appearance.

Miami now includes its 13 supplied models and 58 matching textures as standalone addons. The 136 unmatched replacement textures need the absent source models and are not streamed; see MIAMI-IMPORT-AUDIT.json in flrp-eup. This is a partial conversion, not all legacy wardrobe presets.

The FHP jacket chest-label smear was fixed in eight YTDs. Skin showing at the sleeves still needs an in-game fit check with compatible arms; the texture fix does not change geometry.

Validation: 716 binary assets, seven collections, every component/hat reference, duplicate names, YTD readback and mocked command/catalog tests. Live rendering and outfit saving are not verified.

Deployment source: deploy/sync-content.sh defaults to the Gitea hub (https://git.flrp.us/flrp); the user-designated push targets are GitHub. The hub must mirror those commits before a host using that default receives them. Reconnect after the new clothing metadata is deployed. A GitHub push alone does not verify a live update.
