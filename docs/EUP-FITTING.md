# FLRP department clothing

The configuration starts `fhp-eup`, `bso-eup` and `flrp-vests` from the flrp-eup content repo. Keep one copy of each original collection. Git LFS assets must be downloaded before starting them.

On an MP freemode character, close vMenu and use `/fhp list` or `/bso list` to print collection-local and current vMenu global IDs. Apply individual pieces using `/fhp top 0 0` or `/bso top 0 0`; select compatible arms, undershirt and shoes in vMenu. The helpers can restore their fitting snapshot with `/fhp restore` or `/bso restore`.

The Endeavor vest supports MP male only. Use `/flrpvest fhp`, `/flrpvest bso` or `/flrpvest mpd`. Optional final gear ID 0–8 applies matching supplied gear, e.g. `/flrpvest bso 8`. Vest textures are 0 FHP, 1 BSO, 2 Miami Police. Save before fitting and save the final outfit through vMenu Player Appearance.

The commands are local appearance helpers and are not restricted by a framework/job. The Miami version here is the shared vest, not a standalone Miami uniform pack.

After syncing, restart the server/resources and reconnect. Check both front and back, arms/clipping, hats, texture selection and saved appearance reload. Repository checks cover assets/metadata and mocked command behavior; live rendering and server entitlement were not tested.

Deployment source: `deploy/sync-content.sh` defaults to the existing Gitea hub (`https://git.flrp.us/flrp`). The changes were pushed to the user-designated GitHub repos. If the host uses the default hub, it must receive the corresponding mirrored commits before deployment; a GitHub push alone does not prove the live server has updated.
