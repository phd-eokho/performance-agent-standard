#!/usr/bin/env bash
# ---
# purpose: Runs hook fixture cases (tests/hooks/cases.tsv) and reports deny/allow mismatches.
# ---

set -euo pipefail

NC='\033[0m'

log_info() {
  local green='\033[0;32m'
  printf "%b[INFO]%b %s\n" "$green" "$NC" "$1"
}

log_error() {
  local red='\033[0;31m'
  printf "%b[ERROR]%b %s\n" "$red" "$NC" "$1" >&2
}

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CASES=${CASES:-"${ROOT}/tests/hooks/cases.tsv"}

pass=0
fail=0
while IFS=$'\t' read -r hook expect payload; do
  [[ -z "$hook" || "$hook" == \#* ]] && continue
  out=$(printf "%s" "$payload" | bash "${ROOT}/scripts/hooks/pre-tool/${hook}.sh")
  got=allow
  printf "%s" "$out" | grep -q '"permissionDecision":"deny"' && got=deny
  if [[ "$got" == "$expect" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    log_error "${hook}: expected ${expect}, got ${got}: ${payload}"
  fi
done < "$CASES"

log_info "hook cases: ${pass} passed, ${fail} failed"
[[ "$fail" -eq 0 ]]
