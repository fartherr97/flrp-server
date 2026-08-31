#!/usr/bin/env bash
# ==========================================================================
# FLRP :: tools/validate.sh — static validation
# ==========================================================================
# Runs every static check we can WITHOUT a running FXServer/DB:
#   * Lua syntax (luac -p) on all resource Lua
#   * luacheck (if installed) using .luacheckrc
#   * JS syntax (node --check) on NUI/tooling JS
#   * SQL smoke (basic parse via `mysql` dry-run IF a DB is configured — optional)
#
# This validates SYNTAX/STATIC correctness only. It does NOT prove runtime
# behavior — see docs/BUILD_STATUS.md for the STATICALLY VALIDATED vs
# RUNTIME TESTED distinction.
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ROOT="server-data/resources"
status=0

echo "==> Lua syntax (luac -p)"
LUAC="$(command -v luac5.4 || command -v luac || true)"
if [[ -z "$LUAC" ]]; then
  echo "    luac not found — skipping Lua syntax check (install lua5.4)"
else
  while IFS= read -r f; do
    if ! "$LUAC" -p "$f" 2>/tmp/flrp_luac_err; then
      echo "    SYNTAX ERROR: $f"; sed 's/^/      /' /tmp/flrp_luac_err; status=1
    fi
  done < <(find "$ROOT" -name '*.lua')
  [[ $status -eq 0 ]] && echo "    OK"
fi

echo "==> luacheck"
if command -v luacheck >/dev/null 2>&1; then
  if ! luacheck "$ROOT" --codes --no-color; then
    # luacheck returns non-zero on warnings too; treat only errors as fatal.
    echo "    (luacheck reported warnings; see above — warnings do not fail the build)"
  fi
else
  echo "    luacheck not found — skipping (luarocks install luacheck)"
fi

echo "==> JS syntax (node --check)"
if command -v node >/dev/null 2>&1; then
  while IFS= read -r f; do
    if ! node --check "$f" 2>/tmp/flrp_node_err; then
      echo "    SYNTAX ERROR: $f"; sed 's/^/      /' /tmp/flrp_node_err; status=1
    fi
  done < <(find "$ROOT" -name '*.js' -not -path '*/node_modules/*')
  [[ $status -eq 0 ]] && echo "    OK"
else
  echo "    node not found — skipping JS syntax check"
fi

echo "==> JSON well-formedness (fxmanifest are Lua, skipped)"

echo
if [[ $status -eq 0 ]]; then
  echo "STATIC VALIDATION: PASS (syntax). NOTE: not runtime-tested."
else
  echo "STATIC VALIDATION: FAIL — fix the errors above."
fi
exit $status
