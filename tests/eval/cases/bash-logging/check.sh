#!/usr/bin/env bash
# Checks rules/bash.md: strict mode, printf, standard log functions (global NC, local color, errors to stderr).
set -euo pipefail
f="$1/cleanup.sh"
[[ -f "$f" ]] || {
  printf "cleanup.sh missing\n"
  exit 1
}
fail=0
expect() { grep -Eq -- "$1" "$f" || {
  printf "missing: %s\n" "$2"
  fail=1
}; }
reject() {
  grep -Eq -- "$1" "$f" && {
    printf "found: %s\n" "$2"
    fail=1
  }
  return 0
}
expect '^set -euo pipefail' 'set -euo pipefail'
expect "^NC='\\\\033\[0m'" "global NC constant"
expect 'log_(info|error)\(\) *\{ *(local [a-z]+=|$)' 'log_* level function'
expect 'local (green|red)=' 'color declared local inside log function'
expect 'log_error\(\).*>&2|>&2' 'errors written to stderr'
reject '(^|[[:space:];])echo[[:space:]]' 'echo instead of printf'
exit "$fail"
