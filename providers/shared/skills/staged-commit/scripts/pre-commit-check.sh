#!/usr/bin/env bash
# ---
# purpose: Pre-flight check for staged-commit skill. Validates git environment and staged changes.
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

# 1. Verify git command exists
command -v git &> /dev/null || {
  log_error "git command not found."
  exit 1
}

# 2. Verify we are in a git repository
git rev-parse --is-inside-work-tree &> /dev/null || {
  log_error "Not in a git repository."
  exit 1
}

# 3. Check for staged changes
staged_count=$(git diff --cached --numstat | wc -l)

[[ "${staged_count}" -eq 0 ]] && {
  log_error "No staged changes found. Please stage files before committing."
  printf "\nUnstaged files:\n"
  git status --short
  exit 1
}

log_info "${staged_count} file(s) staged for commit."
diff_file=$(mktemp /tmp/commit-diff-XXXXXX.patch)
trap 'rm -f "$diff_file"' EXIT
git diff --cached > "$diff_file"
staged_lines=$(wc -l < "$diff_file")

printf "STAGED_COUNT=%s\n" "$staged_count"
printf "STAGED_LINES=%s\n" "$staged_lines"
printf "DIFF_FILE=%s\n" "$diff_file"

# Preserve the diff file for the agent — disable cleanup trap
trap - EXIT
