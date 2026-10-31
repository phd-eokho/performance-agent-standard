#!/usr/bin/env bash
# ---
# purpose: Removes per-session hook state for the ending session and sweeps state older than 24 hours.
# ---

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

STATE_ROOT=${TMPDIR:-/tmp}
STALE_MINUTES=${STALE_MINUTES:-1440}

session=$(pas_session | tr -cd 'a-zA-Z0-9_-')
[[ -n "$session" ]] && rm -rf "${STATE_ROOT}/pas-session-${session}"
find "$STATE_ROOT" -maxdepth 1 -type d -name 'pas-session-*' -mmin "+${STALE_MINUTES}" -exec rm -rf {} + 2> /dev/null || true
exit 0
