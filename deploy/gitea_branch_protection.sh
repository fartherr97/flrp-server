#!/usr/bin/env bash
# ==========================================================================
# FLRP :: deploy/gitea_branch_protection.sh — protect `main` via Gitea API
# ==========================================================================
# Applies a branch-protection rule to `main` on a Gitea repo: no direct pushes
# (PRs only), required approvals, dismiss stale approvals, require CODEOWNERS
# review, and block force-push / deletion. Run once per repo you want protected
# (the core repo, and each content repo).
#
# You provide credentials via env (never commit a token):
#   GITEA_URL    e.g. https://gitea.internal.example       (no trailing slash)
#   GITEA_TOKEN  a Gitea access token with repo admin scope
#   OWNER        org/user that owns the repo, e.g. flrp
#   REPO         repo name, e.g. flrp-server
# Optional:
#   BRANCH       default: main
#   APPROVALS    default: 1
#
# Example:
#   GITEA_URL=https://gitea.internal GITEA_TOKEN=xxxxx OWNER=flrp REPO=flrp-server \
#     deploy/gitea_branch_protection.sh
#
# Docs: https://docs.gitea.com/api  (Repository -> branch_protections)
# ==========================================================================
set -euo pipefail

: "${GITEA_URL:?set GITEA_URL}"
: "${GITEA_TOKEN:?set GITEA_TOKEN}"
: "${OWNER:?set OWNER}"
: "${REPO:?set REPO}"
BRANCH="${BRANCH:-main}"
APPROVALS="${APPROVALS:-1}"

API="${GITEA_URL%/}/api/v1/repos/${OWNER}/${REPO}/branch_protections"

read -r -d '' BODY <<JSON || true
{
  "rule_name": "${BRANCH}",
  "branch_name": "${BRANCH}",
  "enable_push": false,
  "enable_push_whitelist": false,
  "require_signed_commits": false,
  "enable_merge_whitelist": false,
  "required_approvals": ${APPROVALS},
  "dismiss_stale_approvals": true,
  "enable_approvals_whitelist": false,
  "block_on_rejected_reviews": true,
  "block_on_official_review_requests": true,
  "block_on_outdated_branch": true,
  "enable_code_owner_review": true,
  "protected_file_patterns": ""
}
JSON

echo "==> Protecting ${OWNER}/${REPO}@${BRANCH} (approvals=${APPROVALS}, CODEOWNERS review required)"

# Create the rule; if it already exists (422), fall back to editing it.
http_code=$(curl -s -o /tmp/flrp_bp.out -w "%{http_code}" -X POST "$API" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$BODY")

if [[ "$http_code" == "201" ]]; then
  echo "    created."
elif [[ "$http_code" == "422" || "$http_code" == "409" ]]; then
  echo "    rule exists — updating via PATCH."
  curl -s -o /tmp/flrp_bp.out -w "    PATCH %{http_code}\n" -X PATCH "${API}/${BRANCH}" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$BODY"
else
  echo "    ERROR: HTTP ${http_code}"; cat /tmp/flrp_bp.out; exit 1
fi

echo "Done. Verify in Gitea: Settings -> Branches -> Branch protection."
