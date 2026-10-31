#!/usr/bin/env bash
# ---
# purpose: Delivers plugin rules into agent context on platforms whose plugins cannot ship rules (Claude Code).
# ---
# Usage: inject-rules.sh session   (SessionStart: core + always_on rules; resets per-session markers)
#        inject-rules.sh file      (PreToolUse on read/edit: glob rules matching the file, once per session)
# Rule files use the agy frontmatter emitted by compile.sh: `trigger: always_on|glob` and `globs: "a, b"`.

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

PLUGIN_ROOT=${PLUGIN_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"}
RULES_DIR="${PLUGIN_ROOT}/rules"
STATE_ROOT=${TMPDIR:-/tmp}

# Prints a frontmatter key value (quotes stripped). Arguments: key, file.
fm_value() {
  awk -v k="$1" '/^---$/ {n++; next} n == 1 && index($0, k ": ") == 1 {v = substr($0, length(k) + 3); gsub(/^"|"$/, "", v); print v; exit}' "$2"
}

# Prints the rule body without frontmatter.
rule_body() {
  awk 'n >= 2 {print} /^---$/ && n < 2 {n++}' "$1"
}

# Returns 0 if the path matches any pattern of a comma-separated glob list (`*` crosses directories).
matches_globs() {
  local path="$1" glob globs=()
  IFS=',' read -ra globs <<< "$2"
  for glob in "${globs[@]}"; do
    glob="${glob#"${glob%%[![:space:]]*}"}"
    # shellcheck disable=SC2053  # intentional pattern match
    [[ "$path" == $glob ]] && return 0
  done
  return 1
}

# Prints "<glob count>\t<rule>" for each undelivered glob rule matching the path. Arguments: path, state dir.
pending_rules() {
  local rule globs
  for rule in "${RULES_DIR}"/*.md; do
    [[ -e "${2}/${rule##*/}" ]] && continue
    [[ "$(fm_value trigger "$rule")" == "glob" ]] || continue
    globs=$(fm_value globs "$rule")
    matches_globs "$1" "$globs" || continue
    printf '%s\t%s\n' "$(tr -cd ',' <<< "$globs" | wc -c)" "$rule"
  done
}

session=$(pas_session | tr -cd 'a-zA-Z0-9_-')
state="${STATE_ROOT}/pas-session-${session:-default}"

case "${1:-}" in
  session)
    # New, cleared, or compacted context: previously injected rules are gone, so markers reset.
    rm -rf "$state"
    mkdir -p "$state"
    text=""
    [[ -f "${RULES_DIR}/AGENTS.md" ]] && text=$(cat "${RULES_DIR}/AGENTS.md")
    for rule in "${RULES_DIR}"/*.md; do
      [[ "$(fm_value trigger "$rule")" == "always_on" ]] && text+=$'\n\n'"$(rule_body "$rule")"
    done
    [[ -n "$text" ]] && pas_context SessionStart "$text"
    ;;
  file)
    target=$(pas_file)
    [[ -n "$target" ]] || exit 0
    mkdir -p "$state"
    text=""
    # General before specific (broader glob list first); precedence itself is stated in AGENTS.md.
    while IFS=$'\t' read -r _ rule; do
      text+="$(rule_body "$rule")"$'\n\n'
      : > "${state}/${rule##*/}"
    done < <(pending_rules "$target" "$state" | sort -t$'\t' -k1,1nr -k2,2)
    [[ -n "$text" ]] && pas_context PreToolUse "$text"
    ;;
  *)
    printf "usage: %s session|file\n" "${0##*/}" >&2
    exit 1
    ;;
esac
exit 0
