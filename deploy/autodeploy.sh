#!/usr/bin/env bash
# ==========================================================================
# FLRP :: deploy/autodeploy.sh — poll-based VPS auto-deploy
# ==========================================================================
# Runs on the VPS from cron every couple of minutes. Checks the tracked branch
# on origin; if there is a new commit, it hard-resets the working tree to match
# origin (the repo is the source of truth), pulls LFS content, and restarts the
# FXServer so the change goes live. No inbound webhook / open port required.
#
# Untracked files (config/secrets.cfg, resources/[core]/vMenu,
# resources/[deps]/oxmysql, cloned content repos) are NOT touched by the reset.
#
# One-time setup on the VPS (see docs/VPS_SETUP.md "Phase 7"):
#   chmod +x /opt/fivem/flrp-server/deploy/autodeploy.sh
#   echo "ubuntu ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fivem" \
#     | sudo tee /etc/sudoers.d/flrp-deploy
#   (crontab -l 2>/dev/null; echo "*/2 * * * * /opt/fivem/flrp-server/deploy/autodeploy.sh >> /opt/fivem/autodeploy.log 2>&1") | crontab -
# ==========================================================================
set -euo pipefail

REPO="${FLRP_REPO:-/opt/fivem/flrp-server}"
BRANCH="${FLRP_BRANCH:-claude/flrp-server-foundation-5aywrh}"
RESTART_CMD="${FLRP_RESTART_CMD:-sudo /usr/bin/systemctl restart fivem}"

cd "$REPO"

# Fetch just the tracked branch; quiet on no-op so the cron log stays clean.
git fetch origin "$BRANCH" --quiet

LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/$BRANCH")"

# Up to date -> nothing to do (exit silently so cron doesn't spam the log).
[ "$LOCAL" = "$REMOTE" ] && exit 0

echo "$(date -u '+%Y-%m-%d %H:%M:%SZ') deploy: ${LOCAL:0:8} -> ${REMOTE:0:8}"

# Repo is the source of truth: match origin exactly. Only tracked files change;
# untracked host files (secrets, vMenu, oxmysql, content) are left alone.
git reset --hard "origin/$BRANCH" --quiet
git lfs pull >/dev/null 2>&1 || true

# Bring the change live. (Full restart for now; players are briefly dropped.
# Refine to per-resource hot-reload once there is a live playerbase.)
$RESTART_CMD

echo "$(date -u '+%Y-%m-%d %H:%M:%SZ') deploy: restarted, now at ${REMOTE:0:8}"
