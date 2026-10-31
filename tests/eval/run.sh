#!/usr/bin/env bash
# ---
# purpose: Measures whether each rule changes agent behavior: runs eval cases through `agy -p` with the plugin enabled and (optionally) disabled.
# ---
# Each case dir holds `prompt.txt`, optional `fixture/` (copied into a fresh temp workspace), and `check.sh`
# (called as `check.sh <workspace> <trace>`; exit 0 = pass). Every run also fails if the agent searched for rule files.
# Agents run sandboxed (`--sandbox`) with only file edits auto-approved (`--mode accept-edits`).
#
# Usage: tests/eval/run.sh [--model M] [--runs N] [--case GLOB] [--baseline]
#   --baseline  also run with the plugin disabled (re-enabled on exit) to measure each rule's effect

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
PLUGIN_NAME="performance-agent-standards"
MODEL=${MODEL:-gemini-3.8-flash-low}
RUNS=${RUNS:-3}
CASE_GLOB=${CASE_GLOB:-*}
TIMEOUT=${TIMEOUT:-300s}
OUT_DIR=${OUT_DIR:-"${ROOT}/tests/eval/out"}
BASELINE=false

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="${2:?}"
      shift 2
      ;;
    --runs)
      RUNS="${2:?}"
      shift 2
      ;;
    --case)
      CASE_GLOB="${2:?}"
      shift 2
      ;;
    --baseline)
      BASELINE=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

command -v agy &> /dev/null || {
  log_error "agy not found."
  exit 1
}
agy plugin list --json | jq -e --arg n "$PLUGIN_NAME" 'any(.[]; .name == $n and .enabled)' > /dev/null ||
  {
    log_error "Install and enable ${PLUGIN_NAME} first: scripts/install.sh --provider antigravity --source ."
    exit 1
  }

# The agent searched for rule files instead of having them loaded (the failure this plugin layout prevents).
RULE_SEARCH='(find|ls|fd|grep_search|find_by_name).{0,200}(rules/|AGENTS\.md|(code|native|rust|cpp|python|bash|markdown)\.md)'

# Runs one case once in a fresh temp workspace. Arguments: case dir, mode label. Prints pass|fail.
run_case() {
  local case_dir="$1" mode="$2" ws trace verdict=fail
  ws=$(mktemp -d)
  trace="${OUT_DIR}/${mode}/${case_dir##*/}.$(date +%s%N).ndjson"
  mkdir -p "${trace%/*}"
  [[ -d "${case_dir}/fixture" ]] && cp -r "${case_dir}/fixture/." "$ws/"
  (cd "$ws" && agy -p "$(cat "${case_dir}/prompt.txt")" --model "$MODEL" --output-format stream-json \
    --sandbox --mode accept-edits --print-timeout "$TIMEOUT" > "$trace" 2>&1) || true
  if [[ "$mode" == "plugin" ]] && grep -Eq "$RULE_SEARCH" "$trace"; then
    printf "rule-file search detected\n" > "${trace%.ndjson}.check.log"
  elif bash "${case_dir}/check.sh" "$ws" "$trace" > "${trace%.ndjson}.check.log" 2>&1; then
    verdict=pass
  fi
  rm -rf "$ws"
  printf "%s\n" "$verdict"
}

# Runs all selected cases RUNS times. Argument: mode label. Prints "<case> <passes>".
run_suite() {
  local mode="$1" case_dir passes i
  for case_dir in "${ROOT}"/tests/eval/cases/${CASE_GLOB}/; do
    case_dir="${case_dir%/}"
    [[ -f "${case_dir}/check.sh" ]] || continue
    passes=0
    for ((i = 1; i <= RUNS; i++)); do
      [[ "$(run_case "$case_dir" "$mode")" == pass ]] && passes=$((passes + 1))
    done
    printf "%s %s\n" "${case_dir##*/}" "$passes"
  done
}

log_info "model=${MODEL} runs=${RUNS} cases=${CASE_GLOB}"
declare -A with_plugin=() without_plugin=()
while read -r name passes; do with_plugin[$name]=$passes; done < <(run_suite plugin)

if [[ "$BASELINE" == true ]]; then
  trap 'agy plugin enable "$PLUGIN_NAME" >/dev/null' EXIT
  agy plugin disable "$PLUGIN_NAME" > /dev/null
  while read -r name passes; do without_plugin[$name]=$passes; done < <(run_suite baseline)
fi

printf "\n%-22s %8s %8s  %s\n" "case" "plugin" "baseline" "verdict"
for name in $(printf "%s\n" "${!with_plugin[@]}" | sort); do
  p=${with_plugin[$name]}
  b=${without_plugin[$name]:--}
  verdict="keep"
  ((p * 3 < RUNS * 2)) && verdict="not followed: sharpen the rule"
  [[ "$b" != "-" ]] && ((p <= b)) && verdict="no effect: delete or rewrite"
  printf "%-22s %5s/%-2s %5s/%-2s  %s\n" "$name" "$p" "$RUNS" "$b" "$RUNS" "$verdict"
done
log_info "Traces: ${OUT_DIR}"
