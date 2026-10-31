#!/usr/bin/env bash
# ---
# purpose: Removes files that pre-plugin installer versions merged into global agent configuration.
# ---
# Only items identified by this project's markers, rule names, skill names, or hook paths are touched.
# Prints the plan first and asks for confirmation unless --yes is given.

set -euo pipefail

NC='\033[0m'
log_info() {
  local green='\033[0;32m'
  printf "%b[INFO]%b %s\n" "$green" "$NC" "$1"
}
log_warn() {
  local yellow='\033[1;33m'
  printf "%b[WARN]%b %s\n" "$yellow" "$NC" "$1" >&2
}
log_error() {
  local red='\033[0;31m'
  printf "%b[ERROR]%b %s\n" "$red" "$NC" "$1" >&2
}

PLUGIN_NAME="performance-agent-standards"
MARK_BEGIN="# --- ${PLUGIN_NAME} rules begin ---"
MARK_END="# --- ${PLUGIN_NAME} rules end ---"
LEGACY_RULES="karpathy-guidelines|workspace-hygiene|inline-execution|development-standards|markdown-writing|markdown-reading|code-simplicity|lang-standard-[a-z0-9-]+"
LEGACY_SKILLS=(build-permission create-pr review-cpp review-python review-rust staged-commit)
ASSUME_YES=false
[[ "${1:-}" == "--yes" ]] && ASSUME_YES=true

command -v jq &> /dev/null || {
  log_error "jq is required."
  exit 1
}

plan=()
add() {
  plan+=("$1")
  printf "  - %s\n" "$2"
}

log_info "Scanning for legacy installer leftovers..."

# Merged rule blocks in global instruction files.
for f in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
  [[ -f "$f" ]] && grep -qF "$MARK_BEGIN" "$f" && add "blocks:$f" "$(grep -cF "$MARK_BEGIN" "$f") marked rule block(s) in $f"
done

# Copied rule files.
for f in "$HOME"/.claude/rules/*.md; do
  [[ -f "$f" ]] && [[ "${f##*/}" =~ ^[0-9]{2}-(${LEGACY_RULES})\.md$ ]] && add "file:$f" "rule file $f"
done

# Copied skills (directories carrying this project's skill names).
for s in "${LEGACY_SKILLS[@]}"; do
  [[ -d "$HOME/.claude/skills/$s" ]] && add "dir:$HOME/.claude/skills/$s" "skill directory $HOME/.claude/skills/$s"
  [[ -d "$HOME/.codex/skills/$s" ]] && add "dir:$HOME/.codex/skills/$s" "skill directory $HOME/.codex/skills/$s"
done

# Hook entries pointing into the legacy plugin script directories.
for f in "$HOME/.claude/settings.json" "$HOME/.codex/settings.json"; do
  [[ -f "$f" ]] || continue
  n=$(jq --arg p "plugins/${PLUGIN_NAME}/scripts/" '[.hooks // {} | .[][]?.hooks[]? | select((.command // "") | contains($p))] | length' "$f")
  [[ "$n" -gt 0 ]] && add "hooks:$f" "${n} hook command(s) in $f"
done

# Plugin directories of removed providers and pre-marketplace Claude layout.
for d in "$HOME/.codex/plugins/${PLUGIN_NAME}" "$HOME/.gemini/plugins/${PLUGIN_NAME}"; do
  [[ -d "$d" ]] && add "dir:$d" "legacy plugin directory $d"
done
d="$HOME/.claude/plugins/${PLUGIN_NAME}"
[[ -d "$d" && ! -f "$d/.claude-plugin/marketplace.json" ]] && add "dir:$d" "pre-marketplace plugin directory $d"

[[ "${#plan[@]}" -gt 0 ]] || {
  log_info "Nothing to migrate."
  exit 0
}

if [[ "$ASSUME_YES" == false ]]; then
  [[ -t 0 ]] || {
    log_error "Run interactively or pass --yes."
    exit 1
  }
  printf "Remove the items above? [y/N] "
  read -r answer
  [[ "$answer" == [yY] ]] || {
    log_warn "Aborted; nothing changed."
    exit 0
  }
fi

for item in "${plan[@]}"; do
  kind="${item%%:*}"
  target="${item#*:}"
  case "$kind" in
    file) rm -f "$target" ;;
    dir) rm -rf "$target" ;;
    blocks)
      tmp=$(mktemp)
      awk -v b="$MARK_BEGIN" -v e="$MARK_END" '$0 == b {skip = 1; next} $0 == e {skip = 0; next} !skip' "$target" |
        cat -s > "$tmp"
      cp "$target" "${target}.bak"
      mv "$tmp" "$target"
      log_info "Backup kept: ${target}.bak"
      ;;
    hooks)
      tmp=$(mktemp)
      jq --arg p "plugins/${PLUGIN_NAME}/scripts/" '
        if .hooks then .hooks |= (map_values(
          map(.hooks |= map(select((.command // "") | contains($p) | not))) | map(select(.hooks | length > 0))
        ) | with_entries(select(.value | length > 0))) else . end' "$target" > "$tmp"
      cp "$target" "${target}.bak"
      mv "$tmp" "$target"
      log_info "Backup kept: ${target}.bak"
      ;;
  esac
done

log_info "Migration complete. Install the plugin with scripts/install.sh."
