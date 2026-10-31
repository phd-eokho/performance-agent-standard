#!/usr/bin/env bash
# ---
# purpose: PostToolUse hook running the repository's prek (pre-commit) checks on the edited file and reporting failures to the agent.
# ---

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

MAX_LOG_LINES=${MAX_LOG_LINES:-10}

target=$(pas_file)
workspace=$(pas_workspace)
[[ -n "$target" && -f "$target" ]] || exit 0

# Hooks may run from the plugin folder (agy), so resolve the repository from the edited file.
repo=$(git -C "$(dirname "$target")" rev-parse --show-toplevel 2> /dev/null || git -C "${workspace:-.}" rev-parse --show-toplevel 2> /dev/null || true)
[[ -n "$repo" ]] || exit 0
[[ -f "${repo}/.pre-commit-config.yaml" || -f "${repo}/prek.toml" ]] || exit 0
prek="${repo}/.venv/bin/prek"
[[ -x "$prek" ]] || exit 0

log=$(cd "$repo" && "$prek" run --files "$target" --color=never 2>&1) && exit 0

lines=$(printf "%s\n" "$log" | wc -l)
summary=$(printf "%s\n" "$log" | head -n "$MAX_LOG_LINES")
((lines > MAX_LOG_LINES)) && summary+=$'\n'"... (${lines} lines, truncated)"
pas_feedback "prek checks failed for ${target}:"$'\n'"${summary}"
