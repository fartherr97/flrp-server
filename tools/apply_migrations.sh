#!/usr/bin/env bash
# ==========================================================================
# FLRP :: tools/apply_migrations.sh — apply DB migrations in order
# ==========================================================================
# Applies database/migrations/*.sql in numeric order using the `mysql` client.
# Migrations are idempotent, so re-running is safe. Provide connection details
# via env vars or flags.
#
#   Env:  FLRP_DB_HOST FLRP_DB_PORT FLRP_DB_USER FLRP_DB_PASS FLRP_DB_NAME
#   Or:   ./apply_migrations.sh -h host -P 3306 -u user -p pass -d flrp
#
# This does NOT read the FiveM convar connection string; keep DB creds in your
# shell/CI, never in Git. See docs/DATABASE.md.
# ==========================================================================
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

HOST="${FLRP_DB_HOST:-127.0.0.1}"
PORT="${FLRP_DB_PORT:-3306}"
USER="${FLRP_DB_USER:-root}"
PASS="${FLRP_DB_PASS:-}"
NAME="${FLRP_DB_NAME:-flrp}"

while getopts "h:P:u:p:d:" opt; do
  case "$opt" in
    h) HOST="$OPTARG" ;; P) PORT="$OPTARG" ;; u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;; d) NAME="$OPTARG" ;;
    *) echo "usage: $0 [-h host] [-P port] [-u user] [-p pass] [-d db]"; exit 1 ;;
  esac
done

if ! command -v mysql >/dev/null 2>&1; then
  echo "ERROR: mysql client not found. Install it or run the .sql files manually."
  exit 1
fi

MYSQL=(mysql --host="$HOST" --port="$PORT" --user="$USER" --protocol=TCP)
[[ -n "$PASS" ]] && MYSQL+=("--password=$PASS")

echo "==> Ensuring database '$NAME' exists"
"${MYSQL[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "==> Applying migrations to '$NAME'"
for f in $(ls database/migrations/*.sql | sort); do
  echo "    - $f"
  "${MYSQL[@]}" "$NAME" < "$f"
done

echo "==> Applied migrations:"
"${MYSQL[@]}" "$NAME" -e "SELECT version, applied_at, description FROM schema_migrations ORDER BY version;"
echo "Done."
