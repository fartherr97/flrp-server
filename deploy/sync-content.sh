#!/usr/bin/env bash
# ==========================================================================
# FLRP :: deploy/sync-content.sh — sync the content repos into the resources
# drop-zones on the HOST. Called by autodeploy.sh after the flrp-server reset.
#
# Idempotent: clone a repo if its drop-zone has no .git yet, otherwise pull.
# Best-effort per repo — a failure here never aborts the FLRP deploy. Prints a
# line beginning "content-changed:" whenever a repo is freshly cloned or a pull
# advances it, so autodeploy knows to restart.
#
# The drop-zones ([scripts] etc.) are gitignored in flrp-server, so these nested
# clones are invisible to the flrp-server working tree and survive its
# `git reset --hard`.
# ==========================================================================
set -uo pipefail

RES="${FLRP_RESOURCES:-/opt/fivem/flrp-server/server-data/resources}"
OWNER="${FLRP_CONTENT_OWNER:-fartherr97}"

sync_one() {
  local dir="$1" repo="$2"
  local target="$RES/$dir"
  local url="https://github.com/$OWNER/$repo.git"

  if [ -d "$target/.git" ]; then
    local before after
    before="$(git -C "$target" rev-parse HEAD 2>/dev/null || echo none)"
    if ! git -C "$target" pull --ff-only --quiet >/dev/null 2>&1; then
      echo "content-sync: pull failed for $repo (leaving as-is)"
      return
    fi
    git -C "$target" lfs pull >/dev/null 2>&1 || true
    after="$(git -C "$target" rev-parse HEAD 2>/dev/null || echo none)"
    [ "$before" != "$after" ] && echo "content-changed: pulled $repo (${before:0:8} -> ${after:0:8})"
  else
    rm -rf "$target"
    if git clone --quiet "$url" "$target" >/dev/null 2>&1; then
      git -C "$target" lfs pull >/dev/null 2>&1 || true
      echo "content-changed: cloned $repo -> $dir"
    else
      echo "content-sync: clone failed for $repo"
      mkdir -p "$target"
    fi
  fi
}

# dir (in resources/)     repo
sync_one "[scripts]"      flrp-scripts
sync_one "[vehicles]"     flrp-vehicles
sync_one "[maps]"         flrp-maps
sync_one "[departments]"  flrp-departments
sync_one "[eup]"          flrp-eup
