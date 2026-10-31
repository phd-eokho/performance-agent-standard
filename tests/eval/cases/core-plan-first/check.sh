#!/usr/bin/env bash
# Checks rules/AGENTS.md: an open question gets a plan, not code changes or new files.
set -euo pipefail
ws="$1"
extra=$(find "$ws" -type f ! -name README.md | head -n 5)
[[ -z "$extra" ]] || {
  printf "created files for a question:\n%s\n" "$extra"
  exit 1
}
[[ "$(cat "$ws/README.md")" == $'# Inventory service\n\nTracks stock levels for warehouses.' ]] ||
  {
    printf "README modified\n"
    exit 1
  }
