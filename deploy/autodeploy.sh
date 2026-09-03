#!/usr/bin/env bash
# ==========================================================================
# FLRP :: deploy/autodeploy.sh — poll-based VPS auto-deploy (surgical reloads)
# ==========================================================================
# Runs on the VPS from cron every couple of minutes. Two jobs:
#   1. flrp-server code: if the tracked branch advanced on origin, hard-reset
#      the working tree to match (the repo is the source of truth) + LFS pull.
#   2. content repos: clone/pull flrp-scripts/vehicles/maps/etc. into the
#      gitignored resources drop-zones (deploy/sync-content.sh).
#
# APPLYING CHANGES — the important bit:
#   A full `systemctl restart fivem` disconnects everyone, so we only do it for
#   STRUCTURAL changes (server.cfg, deps, or content/maps). For ordinary code
#   changes (a flrp_* resource, or a live-execable cfg like permissions.cfg) we
#   write a queue file that the in-server `flrp_hotreload` resource applies LIVE
#   — reloading just those resources / re-exec'ing just those cfgs, with nobody
#   kicked. See resources/[flrp]/flrp_hotreload.
#
# Untracked host files (config/secrets.cfg, resources/[core]/vMenu,
# resources/[deps]/oxmysql, the cloned content drop-zones, and this queue file)
# are never touched by `git reset --hard`.
#
# One-time setup on the VPS (see docs/VPS_SETUP.md "Phase 7"):
#   chmod +x deploy/autodeploy.sh deploy/sync-content.sh
#   echo "ubuntu ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fivem" \
#     | sudo tee /etc/sudoers.d/flrp-deploy
#   Add `ensure flrp_hotreload` to resources.cfg and do ONE full restart to
#   bring it online; after that, deploys hot-reload with no kicks.
#   (crontab -l 2>/dev/null; echo "*/2 * * * * /opt/fivem/flrp-server/deploy/autodeploy.sh >> /opt/fivem/autodeploy.log 2>&1") | crontab -
# ==========================================================================
set -uo pipefail

REPO="${FLRP_REPO:-/opt/fivem/flrp-server}"
BRANCH="${FLRP_BRANCH:-claude/flrp-server-foundation-5aywrh}"
RESTART_CMD="${FLRP_RESTART_CMD:-sudo /usr/bin/systemctl restart fivem}"
QUEUE="${FLRP_HOTRELOAD_QUEUE:-$REPO/deploy/.hotreload.queue}"

cd "$REPO" || exit 1

full_restart=0
declare -A reload_res=()   # resource name -> 1
declare -A reload_cfg=()   # cfg filename -> 1
need_refresh=0

# ---- map a changed repo path to a reload action ---------------------------
classify() {
  local f="$1"
  case "$f" in
    server-data/config/server.cfg)
      full_restart=1 ;;                                   # identity/onesync/build → restart
    server-data/config/resources.cfg)
      need_refresh=1 ;;                                   # new ensures; changed res files reload themselves
    server-data/config/*.cfg)
      reload_cfg["${f##*/}"]=1 ;;                         # permissions/economy/vehicles → exec live
    server-data/resources/*)
      local rel="${f#server-data/resources/}"
      local seg0="${rel%%/*}" res
      if [[ "$seg0" == \[*\] ]]; then                     # bracket category: resource is next segment
        rel="${rel#*/}"; res="${rel%%/*}"
      else
        res="$seg0"
      fi
      # [deps]/[core] are untracked host resources; ignore if they ever appear
      case "$seg0" in \[deps\]|\[core\]) res="" ;; esac
      [ -n "$res" ] && reload_res["$res"]=1 ;;
    *) : ;;                                               # docs/, deploy/, database/ → no reload
  esac
}

# ---- 1. flrp-server code --------------------------------------------------
if git fetch origin "$BRANCH" --quiet 2>/dev/null; then
  LOCAL="$(git rev-parse HEAD)"
  REMOTE="$(git rev-parse "origin/$BRANCH")"
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo "$(date -u '+%F %T')Z deploy: flrp-server ${LOCAL:0:8} -> ${REMOTE:0:8}"
    # classify BEFORE resetting (diff old..new), then reset to new.
    while IFS= read -r f; do [ -n "$f" ] && classify "$f"; done \
      < <(git diff --name-only "$LOCAL" "$REMOTE" 2>/dev/null)
    git reset --hard "origin/$BRANCH" --quiet
    git lfs pull >/dev/null 2>&1 || true
  fi
else
  echo "$(date -u '+%F %T')Z deploy: fetch failed (network?), skipping this run"
  exit 0
fi

# ---- 2. content repos -----------------------------------------------------
# Content (scripts/maps/vehicles) stream assets; safest to bounce the server.
if [ -x "$REPO/deploy/sync-content.sh" ]; then
  sc_out="$(FLRP_RESOURCES="$REPO/server-data/resources" "$REPO/deploy/sync-content.sh" 2>&1 || true)"
  if [ -n "$sc_out" ]; then
    echo "$sc_out"
    if printf '%s\n' "$sc_out" | grep -q "content-changed"; then full_restart=1; fi
  fi
fi

# ---- 3. apply -------------------------------------------------------------
if [ "$full_restart" -eq 1 ]; then
  $RESTART_CMD
  echo "$(date -u '+%F %T')Z deploy: full restart (structural/content change)"
  exit 0
fi

if [ "$need_refresh" -eq 1 ] || [ "${#reload_res[@]}" -gt 0 ] || [ "${#reload_cfg[@]}" -gt 0 ]; then
  tmp="$QUEUE.tmp"
  : > "$tmp"
  [ "$need_refresh" -eq 1 ] && echo "refresh" >> "$tmp"
  for r in "${!reload_res[@]}"; do
    [ "$r" = "flrp_hotreload" ] && continue     # never ask the watcher to reload itself mid-flight
    echo "resource $r" >> "$tmp"
  done
  for c in "${!reload_cfg[@]}"; do echo "cfg $c" >> "$tmp"; done
  mv -f "$tmp" "$QUEUE"                          # atomic hand-off to flrp_hotreload
  echo "$(date -u '+%F %T')Z deploy: queued live reload -> $(tr '\n' ' ' < "$QUEUE")"
else
  echo "$(date -u '+%F %T')Z deploy: changes need no reload (docs/deploy only)"
fi
