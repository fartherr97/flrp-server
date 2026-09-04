#!/usr/bin/env bash
# ==========================================================================
# FLRP :: deploy/sync-content.sh — sync the content repos into the resources
# drop-zones on the HOST. Called by autodeploy.sh after the flrp-server reset.
#
# Idempotent: clone a repo if its drop-zone has no .git yet, otherwise pull.
# Best-effort per repo — a failure here never aborts the FLRP deploy.
#
# APPLYING CHANGES (surgical, so content pushes don't kick everyone):
#   For "reload" repos (scripts/vehicles/eup/departments) an incremental pull
#   prints one `content-reload: <resource>` line per resource folder that
#   changed — autodeploy queues those for flrp_hotreload to `refresh` + restart
#   LIVE (new vehicles stream in without a bounce). Only when it can't tell what
#   changed (a fresh clone, or a diff failure) does it print `content-restart`
#   for a full bounce. The "maps" repo is always `content-restart` — MLOs are
#   unsafe to hot-load.
#
# The drop-zones ([scripts] etc.) are gitignored in flrp-server, so these nested
# clones are invisible to the flrp-server working tree and survive its
# `git reset --hard`.
# ==========================================================================
set -uo pipefail

RES="${FLRP_RESOURCES:-/opt/fivem/flrp-server/server-data/resources}"

# Source of truth for content repos (Gitea hub). Override FLRP_CONTENT_BASE to
# repoint (GitHub backup, or an SSH base like "git@git.flrp.us:flrp").
BASE="${FLRP_CONTENT_BASE:-https://git.flrp.us/flrp}"
BASE="${BASE%/}"

# Map a path INSIDE a content repo to its resource folder name: strip any
# leading [bracket] group segments; the first non-bracket segment is the
# resource. e.g. "[BSO]/BSO18-23PursuitSedans/stream/x.yft" -> BSO18-23PursuitSedans
resource_of() {
  local rel="$1" seg
  while [[ "$rel" == *"/"* ]]; do
    seg="${rel%%/*}"
    case "$seg" in
      \[*\]) rel="${rel#*/}" ;;   # bracket group — descend into it
      *)     break ;;             # first real folder is the resource
    esac
  done
  seg="${rel%%/*}"
  # a bare file at the repo root (e.g. content.cfg) is not a resource
  case "$seg" in *.*) return 1 ;; esac
  printf '%s\n' "$seg"
}

# dir (in resources/)   repo             mode(reload|restart)
sync_one() {
  local dir="$1" repo="$2" mode="$3"
  local target="$RES/$dir"
  local url="$BASE/$repo.git"

  if [ -d "$target/.git" ]; then
    local before after
    before="$(git -C "$target" rev-parse HEAD 2>/dev/null || echo none)"
    if ! git -C "$target" pull --ff-only --quiet >/dev/null 2>&1; then
      echo "content-sync: pull failed for $repo (leaving as-is)"; return
    fi
    git -C "$target" lfs pull >/dev/null 2>&1 || true
    after="$(git -C "$target" rev-parse HEAD 2>/dev/null || echo none)"
    [ "$before" = "$after" ] && return                       # nothing changed

    if [ "$mode" = "restart" ]; then
      echo "content-restart: $repo (${before:0:8} -> ${after:0:8})"; return
    fi
    # reload mode: emit one line per changed resource folder
    local changed diff
    diff="$(git -C "$target" diff --name-only "$before" "$after" 2>/dev/null)"
    if [ -z "$diff" ]; then
      echo "content-restart: $repo (diff unavailable — full bounce)"; return
    fi
    changed="$(while IFS= read -r f; do [ -n "$f" ] && resource_of "$f"; done <<< "$diff" | sort -u)"
    if [ -z "$changed" ]; then
      echo "content-restart: $repo (no mappable resource — full bounce)"; return
    fi
    while IFS= read -r r; do [ -n "$r" ] && echo "content-reload: $r"; done <<< "$changed"
    echo "content-sync: $repo (${before:0:8} -> ${after:0:8}) reloaded live"
  else
    # first-time clone → bring the whole thing up with a full restart (rare)
    rm -rf "$target"
    if git clone --quiet "$url" "$target" >/dev/null 2>&1; then
      git -C "$target" lfs pull >/dev/null 2>&1 || true
      echo "content-restart: cloned $repo -> $dir (first bring-up)"
    else
      echo "content-sync: clone failed for $repo"; mkdir -p "$target"
    fi
  fi
}

sync_one "[scripts]"      flrp-scripts      reload
sync_one "[vehicles]"     flrp-vehicles     reload
sync_one "[maps]"         flrp-maps         restart
sync_one "[departments]"  flrp-departments  reload
sync_one "[eup]"          flrp-eup          reload
