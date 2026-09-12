# Civilian vehicle catalog

Source: installed flrp-vehicles metadata and user tier assignments. Years are shown where supplied by model names or metadata; unknown years are omitted. Unverified personal donor names retain their existing registry labels rather than inventing a vehicle identity.

Corrections: {'o9chargerciv': '09chargerciv', 'faltbedm2': 'flatbedm2', 'corollscross20': 'corollacross20', 'teslex': 'teslax'}

Not spawnable: 13tahoeciv, 16explorerciv, c8n, waf. The two c8n/waf entries are mod-kit parts, not registered vehicles. 13tahoeciv and 16explorerciv are absent from vehicles.meta. No substitute was assigned.

Vanilla audit: 921 models from https://github.com/DurtyFree/gta-v-data-dumps/blob/master/vehicles.json; 153 blocked. Weapons exclude searchlights and water cannons. Ordinary civilian aircraft remain allowed.


Metadata present but no streamed YFT: 09chargerciv, 13capriceciv, raptor2017, laferrari, mustangbkit, m3e36normal, pjtrailer, cararv, guardianrv, sandkingrv. Registered disabled; omitted from the interaction menu. Existing disabled flags are preserved.

Personal donor packs, dev personals and personal tow trucks are excluded.

Deployment: apply migration 013, run deploy/configure-vehicle-access.py against the host vMenu folder, then restart resources while the server is empty. Catalog policies are enforced before the general registry bypass setting, including for staff. Director and Ownership retain civilian access; donor models require the actual donor group.
