#!/usr/bin/env bash
# ---
# purpose: PreToolUse hook blocking destructive OS commands, in-place stream edits, and GitHub API mutations.
# ---

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Command position (start, chain, subshell, sudo) and same-segment arguments.
CMD="(^|[;&|(\`]\s*|\\\$\(\s*|sudo\s+)"
SEG="[^|;&]*"

RULES=(
  "${CMD}rm(\s${SEG})?(\s-[a-zA-Z]*r[a-zA-Z]*f|\s-[a-zA-Z]*f[a-zA-Z]*r|\s-[a-zA-Z]*r${SEG}\s-[a-zA-Z]*f|\s-[a-zA-Z]*f${SEG}\s-[a-zA-Z]*r|\s--recursive)${SEG}\s(/|/\*|~|~/|\*|\\\$HOME|\\\$HOME/)(\s|$):::[bash-guard] Root/home/wildcard deletion blocked. Use targeted paths."
  "${CMD}(sed(\s${SEG})?\s(-[a-zA-Z]*i|--in-place)|perl(\s${SEG})?\s-[a-zA-Z]*i|ruby(\s${SEG})?\s-[a-zA-Z]*i|ed\s):::[bash-guard] In-place stream edit blocked. Use workspace file edit tools."
  "${CMD}gh\s+(repo\s+delete|api${SEG}\s(-X\s*|--method[=\s]*)(DELETE|PUT|PATCH)):::[bash-guard] GitHub API mutation blocked. Only read-only queries allowed."
  "${CMD}(dd\s${SEG}\b(if|of)=|mkfs(\.[a-z0-9]+)?\s|wipefs\s|fdisk\s|shred\s|truncate\s${SEG}(-s\s*0|--size=0)\b):::[bash-guard] Disk/filesystem mutation utility blocked."
  "(${CMD}sudo\s|chmod\s+-R\s+777|kill\s+-9\s+-?1(\s|$)|:\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:):::[bash-guard] Unsafe privilege/system operation blocked."
)

pas_guard "$(pas_command)" "${RULES[@]}"
