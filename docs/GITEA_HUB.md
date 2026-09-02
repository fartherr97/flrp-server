# FLRP Git topology — Gitea hub

**Model:** Gitea (`git.flrp.us`, org `flrp`) is the single home. GitHub
(`fartherr97/*`) is an automatic backup. The VPS pulls **only** from Gitea.

```
                 ┌─────────────────────────── GitHub (fartherr97/*) ──────────┐
                 │  backup of everything; authoring remote for CODE only      │
                 └───────▲───────────────────────────────────┬───────────────┘
   push mirror (content) │                                   │ pull mirror (code)
                 ┌───────┴───────────────────────────────────▼───────────────┐
   devs ───push──▶                    Gitea — git.flrp.us/flrp                 │
                 │  SOURCE OF TRUTH. content authored here; code mirrored in   │
                 └───────────────────────────────┬────────────────────────────┘
                                                  │ pull (autodeploy + sync-content)
                                          ┌───────▼────────┐
                                          │   VPS FXServer  │
                                          └────────────────┘
```

- **Content repos** (`flrp-vehicles`, `flrp-maps`, `flrp-eup`, department repos):
  devs push to Gitea. Gitea **push-mirrors → GitHub** as backup.
- **Code repos** (`flrp-server`, `flrp-scripts`): Claude/me pushes to GitHub in
  its work sessions. Gitea **pull-mirrors ← GitHub**, so the code lands in Gitea
  automatically — no Gitea token needed for the session. Code repos are
  read-only in Gitea (that's expected; devs edit content, not code).
- **Website** (`florida-roleplay-site`): deploys on Northflank from GitHub;
  it's not on the VPS, so it stays outside this pipeline. Optionally mirror it
  to Gitea for backup only.

---

## One-time setup

### 1. Gitea org + repos
Under org `flrp` on `git.flrp.us`, make sure these exist:
`flrp-server`, `flrp-scripts`, `flrp-vehicles`, `flrp-maps` (+ `flrp-eup`,
`flrp-bso`, `flrp-fhp`, `flrp-mpd`, `flrp-standalone` as they come online).

### 2. Code repos → pull mirror FROM GitHub
For `flrp-server` and `flrp-scripts`, create them in Gitea as **mirrors**:
**+ New Migration → GitHub →** URL `https://github.com/fartherr97/<repo>.git`,
tick **“This repository will be a mirror.”** Give it a GitHub read token if the
repo is private. Set the mirror interval as low as Gitea allows (e.g. `10m`).
Gitea now auto-pulls every branch — including the deploy branch
`claude/flrp-server-foundation-5aywrh` — from GitHub.

> A pull-mirror repo is read-only in Gitea. That's correct for code.

### 3. Content repos → push mirror TO GitHub
For `flrp-vehicles`, `flrp-maps`, etc. (normal, writable Gitea repos where devs
work): **Repo → Settings → Mirror Settings → Push Mirror → Add:**
- Git Remote URL: `https://github.com/fartherr97/<repo>.git`
- Auth: your GitHub username + a GitHub PAT with **`repo`** scope
- ✅ **Sync when commits are pushed** (plus an interval fallback like `8h`)

Every dev push to Gitea now replicates to GitHub within seconds.

### 4. VPS → pull from Gitea
On the VPS (one-time):

Point the core repo's `origin` at Gitea:
```
git -C /opt/fivem/flrp-server remote set-url origin https://git.flrp.us/flrp/flrp-server.git
```

Point content sync at Gitea — add to the deploy env (e.g. the crontab line or a
`/etc/environment` entry the cron job inherits):
```
FLRP_CONTENT_BASE=https://git.flrp.us/flrp
```
(Already the built-in default in `sync-content.sh`, so this is just to be
explicit / override the old GitHub base on an existing box.)

Give the VPS **read** credentials for private Gitea repos. Simplest: a
read-only Gitea token in the credential store —
```
git config --global credential.helper store
```
then the first pull prompts once for a Gitea username + token and stores it.
(Or use an SSH base `git@git.flrp.us:flrp` with a Gitea **deploy key**.)

### 5. Import the content that's currently only on the VPS
The MPD vehicle pack and the MRPD / Sandy map resources you dropped straight
into the drop-zones need to reach Gitea (the source of truth) so they survive
and reach the devs. History-safe method — clone Gitea fresh, copy the new
folders in, push:

```
cd /opt/fivem
git clone https://git.flrp.us/flrp/flrp-maps.git _maps && git -C _maps lfs install
cp -r 'flrp-server/server-data/resources/[maps]/MRPD' 'flrp-server/server-data/resources/[maps]/cfx_prompt_sandy_mapdata' 'flrp-server/server-data/resources/[maps]/cfx_prompt_sandy_shores_fire_department' _maps/
git -C _maps add -A && git -C _maps commit -m "Add MRPD mapdata, Sandy mapdata + fire department" && git -C _maps push
```
```
git clone https://git.flrp.us/flrp/flrp-vehicles.git _veh && git -C _veh lfs install
cp -r 'flrp-server/server-data/resources/[vehicles]/[MPD]' _veh/
git -C _veh add -A && git -C _veh commit -m "Add MPD Miami vehicle pack" && git -C _veh push
```
Then delete the drop-zones so the next sync re-clones them cleanly from Gitea:
```
rm -rf 'flrp-server/server-data/resources/[maps]' 'flrp-server/server-data/resources/[vehicles]' && rm -rf _maps _veh
cd /opt/fivem/flrp-server/deploy && ./sync-content.sh && ./autodeploy.sh
```

> If a Gitea content repo is still **empty** (no dev content yet), don't just
> copy the new folders — push the whole drop-zone up as the initial import
> instead (set the drop-zone's remote to Gitea and push its full tree).

### 6. Dev onboarding
Devs get Gitea accounts in the `flrp` org and clone/push content over
`https://git.flrp.us/flrp/<repo>.git`. They never need GitHub. Their pushes
mirror to GitHub automatically and reach the VPS on the next 2-minute sync.

---

## Day-to-day
- **Dev edits a vehicle/map** → push to Gitea → mirrors to GitHub → VPS pulls in
  ≤2 min → FXServer restarts only if something changed.
- **Claude edits code** → pushes GitHub → Gitea pull-mirror picks it up (≤10 min)
  → VPS pulls → restart.
- **Backup:** GitHub always holds a full copy of every repo.

## Notes / gotchas
- **LFS:** both hosts must have LFS enabled (Gitea: on by default). New model
  files auto-track via each repo's `.gitattributes`. If a push is rejected for a
  >100 MB non-LFS file, add its extension to `.gitattributes`.
- **No merge step needed:** because each repo has exactly one authoring side
  (content = Gitea, code = GitHub), the "both sides edited the same file"
  conflict can't happen. That's why this is simpler than a dual-remote merge.
- **Mirror direction is one-way per repo.** Never make a repo both a pull mirror
  and a writable dev repo — pick its role (code vs content) and stick to it.
