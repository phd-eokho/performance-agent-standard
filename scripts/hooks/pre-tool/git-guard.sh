#!/usr/bin/env bash
# ---
# purpose: PreToolUse hook blocking destructive Git operations in shell tool calls.
# ---

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# git invocation at a command boundary (start, chain, subshell), optionally behind env assignments or sudo.
GIT="(^|[;&|(\`]\s*|\\\$\(\s*)(sudo\s+|env\s+|[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*git(\s+-[Cc]\s+\S+|\s+-[^[:space:]]+)*\s+"
# Arguments of the same command segment (stops at pipes and chain operators).
SEG="[^|;&]*"

RULES=(
  "${GIT}push${SEG}\s(-[a-zA-Z0-9]*f\b|--force\b|--force-with-lease|--force-if-includes):::[git-guard] Force push blocked. Rebase or pull first."
  "${GIT}reset${SEG}\s--(hard|merge)\b:::[git-guard] Hard/merge reset blocked. Use soft reset or stash."
  "${GIT}clean${SEG}\s(-[a-zA-Z0-9]*f|--force\b):::[git-guard] Untracked file purge (clean -f) blocked. Delete specific paths."
  "${GIT}branch${SEG}\s(-[a-zA-Z0-9]*D\b|(-[a-zA-Z0-9]*d|--delete)${SEG}\s(-[a-zA-Z0-9]*f|--force)\b|(-[a-zA-Z0-9]*f|--force)${SEG}\s(-[a-zA-Z0-9]*d|--delete)\b):::[git-guard] Branch force deletion blocked. Use 'git branch -d'."
  "${GIT}(checkout|restore)(${SEG}\s)?(--\s+)?\.(/)?(\s|$|[;&|)]):::[git-guard] Working tree wipe blocked. Target specific file paths."
  "${GIT}stash\s+(drop|clear)\b:::[git-guard] Stash destruction blocked. Preserve or inspect stashes."
  "${GIT}(commit${SEG}\s-[a-zA-Z0-9]*n\b|(commit|push|merge|rebase|cherry-pick|am)${SEG}\s--no-verify\b):::[git-guard] Hook bypass (--no-verify) blocked. Run validation checks."
)

pas_guard "$(pas_command)" "${RULES[@]}"
