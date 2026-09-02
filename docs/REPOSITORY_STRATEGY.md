# FLRP Repository Strategy (multi-repo + branch protection)

FLRP uses the **SSRP-style split**: one **core** repo for the framework, and
separate **content** repos for vehicles, EUP, maps, departments, etc. — each
with its own access list. `main` on every repo is **protected** (PRs + review
only). This gives per-area contributor access, which Git cannot do inside a
single repo (access is repository-level, never folder-level).

## Why split

- Git/Gitea/GitHub grant access **per repository**, not per folder. To let a
  vehicle contributor in without exposing the core permission/economy code, the
  vehicles must be a **separate repo**.
- Content changes often (new cars, uniforms, maps); the framework changes
  rarely. Separate repos = separate history, separate reviewers, smaller blast
  radius.

## Repo map

| Repo | Contents | Assembled into | Access tier |
|------|----------|----------------|-------------|
| **flrp-server** (this) | `[flrp]` core, `config/`, `database/`, `docs/`, `deploy/`, `tools/` | is the server root | leads / core devs |
| **flrp-vehicles** | vehicle resource packs | `[vehicles]/[flrp-vehicles]/` | vehicle team |
| **flrp-eup** | EUP / uniforms | `[eup]/[flrp-eup]/` | uniform team |
| **flrp-maps** | maps / MLOs | `[maps]/[flrp-maps]/` | mapping team |
| **flrp-bso / flrp-fhp / flrp-mpd** | department glue | `[departments]/[flrp-bso]/` … | department leads |
| **flrp-standalone** | misc standalone resources | `[standalone]/[flrp-standalone]/` | as needed |

Split departments into three repos or keep one `flrp-departments` — your call;
the manifest supports either.

> Third-party dependencies (oxmysql, vMenu) and escrowed/paid assets are **not**
> your repos; they're installed on the host per [INSTALLATION.md](INSTALLATION.md).

## How assembly works (the FiveM bracket detail)

The core repo's `[vehicles]`, `[eup]`, `[maps]`, `[standalone]`,
`[departments]` folders are **drop zones**: their subfolders are gitignored
(`[<category>]/*/`), so anything cloned inside is invisible to the core repo.

`deploy/assemble.sh` reads `deploy/content-repos.manifest` and clones/pulls each
content repo into a **bracketed** subfolder:

```
server-data/resources/[vehicles]/[flrp-vehicles]/<pack>/fxmanifest.lua
                       └ core drop zone
                                    └ content repo clone (bracketed = FiveM group)
```

Bracketing the clone folder matters: FiveM treats `[name]` folders as resource
**groups** and recurses into them, so your packs are discovered. A non-bracket
folder containing multiple resources would be mis-read as one resource.

Each content repo may ship a root `content.cfg` with its `ensure <resource>`
lines; `assemble.sh` regenerates `server-data/config/content.cfg` to `exec`
them, and `server.cfg` execs that. So content repos are self-describing — adding
a car doesn't require editing the core repo.

### Deploy flow (per host)

```
# 1. core repo (this) is checked out as the server root
git -C /srv/flrp/flrp-server pull --ff-only

# 2. assemble content repos into the drop zones
cp deploy/content-repos.manifest.example deploy/content-repos.manifest   # once
$EDITOR deploy/content-repos.manifest                                    # real URLs
deploy/assemble.sh                                                       # clone/pull all

# 3. secrets stay put (never in any repo), DB migrations applied, then start
```

`assemble.sh` is idempotent — re-run it to pull the latest content. Use
`--dry-run` to preview. See [DEPLOYMENT.md](DEPLOYMENT.md).

### Which remote the box pulls from

Point the manifest URLs (and the core checkout) at **Gitea** if the box can
reach it internally — faster and private — or GitHub. GitHub stays the
authoritative upstream you and Claude push to; Gitea is the mirror/deploy
source. Use a **read-only deploy key** per repo on the box.

## Branch protection (`main`)

Protect `main` on **every** repo (core and content). Settings:

- **No direct pushes** — changes land via pull request only.
- **Required approvals: ≥ 1** (raise for core).
- **Require CODEOWNERS review** — routes each path to its owners
  (see `CODEOWNERS`).
- **Dismiss stale approvals** on new commits.
- **Block on outdated branch** / rejected reviews.
- **Block force-push and deletion** of `main`.

### Apply it (Gitea, scripted)

```
GITEA_URL=https://gitea.internal GITEA_TOKEN=<admin token> \
OWNER=flrp REPO=flrp-server APPROVALS=2 \
  deploy/gitea_branch_protection.sh

# repeat per content repo (APPROVALS=1 is fine there)
GITEA_URL=... GITEA_TOKEN=... OWNER=flrp REPO=flrp-vehicles deploy/gitea_branch_protection.sh
```

Or in the UI: **Repo → Settings → Branches → Add Branch Protection** for `main`.

### GitHub equivalent

**Repo → Settings → Branches → Add rule** for `main`: *Require a pull request
before merging* + *Require approvals* + *Require review from Code Owners* +
*Dismiss stale reviews*; disable *Allow force pushes* and *deletions*. Add a
`CODEOWNERS` (already at repo root; also valid in `.github/`).

## CODEOWNERS

The core repo ships a root [`CODEOWNERS`](../CODEOWNERS) mapping `[flrp]`,
`config/`, `database/`, `deploy/`, `docs/` to owner teams (replace the
`@FLRP/...` placeholders with real teams). Each **content** repo gets its own
CODEOWNERS — scaffold one with `tools/new_content_repo.sh`.

CODEOWNERS controls **who must approve** changes to a path; it does not hide
files. That's the point of splitting content into separate repos.

## Creating the content repos

For each area:

1. `tools/new_content_repo.sh flrp-vehicles vehicles` — scaffolds a starter
   content repo (README, `content.cfg`, CODEOWNERS, `.gitignore`, `.keep`).
2. Create the empty repo in Gitea/GitHub, add the team + `main` protection.
3. `git push` the scaffold; drop the real assets in; open PRs.
4. Add a line to `deploy/content-repos.manifest` and run `deploy/assemble.sh`.

## What did NOT change

The GitHub→Gitea **mirror** architecture is untouched: GitHub authoritative,
Gitea mirror. Splitting content into their own repos is orthogonal to mirroring
— each repo can still be mirrored the same way.
