#!/usr/bin/env bash
# ==========================================================================
# FLRP :: deploy/autodeploy.sh — poll-based VPS auto-deploy
# ==========================================================================
# Runs on the VPS from cron every couple of minutes. Two jobs:
#   1. flrp-server code: if the tracked branch advanced on origin, hard-reset
#      the working tree to match (the repo is the source of truth) + LFS pull.
#   2. content repos: clone/pull flrp-scripts/vehicles/maps/etc. into the
#      gitignored resources drop-zones (deploy/sync-content.sh).
# Restart the FXServer only if either produced a change. No inbound webhook or
# open port required.
#
# Untracked host files (config/secrets.cfg, resources/[core]/vMenu,
# resources/[deps]/oxmysql, and the cloned content drop-zones) are never touched
# by the reset.
#
# One-time setup on the VPS (see docs/VPS_SETUP.md "Phase 7"):
#   chmod +x /opt/fivem/flrp-server/deploy/autodeploy.sh
#   chmod +x /opt/fivem/flrp-server/deploy/sync-content.sh
#   echo "ubuntu ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fivem" \
#     | sudo tee /etc/sudoers.d/flrp-deploy
#   (crontab -l 2>/dev/null; echo "*/2 * * * * /opt/fivem/flrp-server/deploy/autodeploy.sh >> /opt/fivem/autodeploy.log 2>&1") | crontab -
# ==========================================================================
set -uo pipefail

REPO="${FLRP_REPO:-/opt/fivem/flrp-server}"
BRANCH="${FLRP_BRANCH:-claude/flrp-server-foundation-5aywrh}"
RESTART_CMD="${FLRP_RESTART_CMD:-sudo /usr/bin/systemctl restart fivem}"

cd "$REPO" || exit 1

changed=0

# 1. flrp-server code -------------------------------------------------------
if git fetch origin "$BRANCH" --quiet 2>/dev/null; then
  LOCAL="$(git rev-parse HEAD)"
  REMOTE="$(git rev-parse "origin/$BRANCH")"
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo "$(date -u '+%F %T')Z deploy: flrp-server ${LOCAL:0:8} -> ${REMOTE:0:8}"
    git reset --hard "origin/$BRANCH" --quiet
    git lfs pull >/dev/null 2>&1 || true
    changed=1
  fi
else
  echo "$(date -u '+%F %T')Z deploy: fetch failed (network?), skipping this run"
  exit 0
fi

# 2. content repos ----------------------------------------------------------
if [ -x "$REPO/deploy/sync-content.sh" ]; then
  sc_out="$(FLRP_RESOURCES="$REPO/server-data/resources" "$REPO/deploy/sync-content.sh" 2>&1 || true)"
  if [ -n "$sc_out" ]; then
    echo "$sc_out"
    if printf '%s\n' "$sc_out" | grep -q "content-changed"; then changed=1; fi
  fi
fi

# 3. restart only if something changed --------------------------------------
if [ "$changed" -eq 1 ]; then
  $RESTART_CMD
  echo "$(date -u '+%F %T')Z deploy: restarted"
fi
