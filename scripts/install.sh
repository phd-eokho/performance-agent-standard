#!/usr/bin/env bash
# ---
# purpose: Installs the plugin through each agent's own plugin manager, then replaces the agent's permission rules with the plugin's read-only policy.
# ---
#   antigravity: agy plugin install            → ~/.gemini/config/plugins/performance-agent-standards/
#   claude:      local marketplace + install   → ~/.claude/plugins/performance-agent-standards/ (+ Claude's plugin cache)
# settings.json: permissions.allow/ask/deny are replaced (other keys kept, previous file backed up next to it).
# Global CLAUDE.md, GEMINI.md, rules/, and skills/ are never modified.

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
REPO_SLUG=${REPO_SLUG:-"phd-eokho/performance-agent-standard"}
PROVIDER=${PROVIDER:-auto}
SOURCE_DIR=${SOURCE_DIR:-}
CLAUDE_MARKETPLACE_DIR=${CLAUDE_MARKETPLACE_DIR:-"$HOME/.claude/plugins/${PLUGIN_NAME}"}
AGY_SETTINGS=${AGY_SETTINGS:-"$HOME/.gemini/antigravity-cli/settings.json"}
CLAUDE_SETTINGS=${CLAUDE_SETTINGS:-"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"}

print_usage() {
  printf "Usage: install.sh [--provider antigravity|claude|auto] [--source <repo-dir>] [--repo <owner/name>]\n"
  printf "  --provider  Agent to install for (default: auto = every installed agent)\n"
  printf "  --source    Compile from a local checkout instead of downloading\n"
  printf "  --repo      GitHub repository (default: %s)\n" "$REPO_SLUG"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --provider)
      PROVIDER="${2:?missing provider}"
      shift 2
      ;;
    --source)
      SOURCE_DIR="${2:?missing directory}"
      shift 2
      ;;
    --repo)
      REPO_SLUG="${2:?missing repo slug}"
      shift 2
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

SETTINGS_TMP=""
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"; [[ -z "$SETTINGS_TMP" ]] || rm -f "$SETTINGS_TMP"' EXIT

# Prints the providers to install for.
resolve_providers() {
  case "$PROVIDER" in
    antigravity | claude) printf "%s\n" "$PROVIDER" ;;
    auto)
      command -v agy &> /dev/null && printf "antigravity\n"
      command -v claude &> /dev/null && printf "claude\n"
      return 0
      ;;
    *)
      log_error "Unknown provider: $PROVIDER"
      exit 1
      ;;
  esac
}

# Prints the compiled plugin directory, from a local checkout, a release archive, or a fresh clone.
fetch_dist() {
  local provider="$1" tag zip

  [[ -n "$SOURCE_DIR" ]] && {
    [[ -d "${TMP_DIR}/dist" ]] || DIST_DIR="${TMP_DIR}/dist" bash "${SOURCE_DIR}/scripts/compile.sh" >&2
    printf "%s\n" "${TMP_DIR}/dist/${provider}"
    return 0
  }

  tag=$(curl -sSf "https://api.github.com/repos/${REPO_SLUG}/releases/latest" 2> /dev/null |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1 || true)
  if [[ -n "$tag" ]]; then
    zip="${TMP_DIR}/${provider}.zip"
    log_info "Downloading ${provider} release ${tag}..." >&2
    curl -sSfL "https://github.com/${REPO_SLUG}/releases/download/${tag}/${PLUGIN_NAME}-${provider}.zip" -o "$zip" &&
      unzip -q "$zip" -d "${TMP_DIR}/${provider}" &&
      {
        printf "%s\n" "${TMP_DIR}/${provider}"
        return 0
      }
    log_warn "Release archive unavailable; compiling from source."
  fi

  [[ -d "${TMP_DIR}/clone" ]] || {
    command -v git &> /dev/null || {
      log_error "git is required to compile from source."
      exit 1
    }
    git clone --quiet --depth 1 "https://github.com/${REPO_SLUG}.git" "${TMP_DIR}/clone" >&2
    DIST_DIR="${TMP_DIR}/clone/dist" bash "${TMP_DIR}/clone/scripts/compile.sh" >&2
  }
  printf "%s\n" "${TMP_DIR}/clone/dist/${provider}"
}

# Prints rules that allow the plugin's own skill scripts, run directly or through bash/sh, under each installed root.
# Arguments: provider, compiled plugin dir, installed plugin roots...
script_rules() {
  local provider="$1" dist="$2" rel root path
  shift 2
  (cd "$dist" && find skills -path '*/scripts/*' -type f -name '*.sh') | sort | while IFS= read -r rel; do
    for root in "$@"; do
      path="${root}/${rel}"
      case "$provider" in
        antigravity) printf 'command(%s)\ncommand(bash %s)\ncommand(sh %s)\n' "$path" "$path" "$path" ;;
        claude) printf 'Bash(%s)\nBash(%s *)\nBash(bash %s)\nBash(bash %s *)\nBash(sh %s)\nBash(sh %s *)\n' \
          "$path" "$path" "$path" "$path" "$path" "$path" ;;
      esac
    done
  done | jq -Rn '[inputs]'
}

# Replaces permissions.allow/ask/deny in the agent's settings with the compiled policy plus the plugin script rules.
# Every other setting is kept; an existing file is first copied to <settings>.<timestamp>.bak.
# Arguments: provider, compiled plugin dir, settings file, installed plugin roots...
override_permissions() {
  local provider="$1" dist="$2" settings="$3" rules backup
  shift 3
  [[ -f "${dist}/permissions.json" ]] || {
    log_warn "No compiled permissions in ${dist}; ${settings} left unchanged."
    return 0
  }
  rules=$(jq --argjson scripts "$(script_rules "$provider" "$dist" "$@")" '.allow += $scripts' "${dist}/permissions.json")
  mkdir -p "$(dirname "$settings")"
  if [[ -f "$settings" ]]; then
    backup="${settings}.$(date +%Y%m%d%H%M%S).bak"
    cp -p "$settings" "$backup"
  else
    backup="none"
    printf '{}\n' > "$settings"
  fi
  SETTINGS_TMP=$(mktemp "${settings}.XXXXXX")
  jq --argjson p "$rules" '.permissions = ((.permissions // {}) + $p)' "$settings" > "$SETTINGS_TMP" || {
    log_error "${settings} is not valid JSON; left unchanged."
    return 1
  }
  mv "$SETTINGS_TMP" "$settings"
  SETTINGS_TMP=""
  log_info "Replaced permission rules in ${settings} (backup: ${backup})"
}

install_antigravity() {
  local dist="$1" root
  command -v agy &> /dev/null || {
    log_error "agy not found."
    return 1
  }
  agy plugin validate "$dist" --strict > /dev/null || {
    log_error "agy rejected the plugin."
    return 1
  }
  agy plugin uninstall "$PLUGIN_NAME" > /dev/null 2>&1 || true
  agy plugin install "$dist"
  log_info "Installed for agy."
  root=$(agy plugin list --json | jq -r --arg n "$PLUGIN_NAME" '.[] | select(.name == $n) | .path // empty')
  [[ -n "$root" ]] || {
    log_error "agy does not report where ${PLUGIN_NAME} is installed."
    return 1
  }
  override_permissions antigravity "$dist" "$AGY_SETTINGS" "$root"
}

install_claude() {
  local dist="$1" roots
  command -v claude &> /dev/null || {
    log_error "claude not found."
    return 1
  }
  # The marketplace directory must persist for updates; it is the plugin's only directory outside Claude's cache.
  rm -rf "$CLAUDE_MARKETPLACE_DIR"
  mkdir -p "$CLAUDE_MARKETPLACE_DIR"
  cp -r "$dist"/. "$CLAUDE_MARKETPLACE_DIR/"
  claude plugin marketplace add "$CLAUDE_MARKETPLACE_DIR" > /dev/null 2>&1 ||
    claude plugin marketplace update "$PLUGIN_NAME" > /dev/null
  claude plugin uninstall "${PLUGIN_NAME}@${PLUGIN_NAME}" > /dev/null 2>&1 || true
  claude plugin install "${PLUGIN_NAME}@${PLUGIN_NAME}"
  log_info "Installed for Claude Code from ${CLAUDE_MARKETPLACE_DIR}"
  # Skills run from the marketplace folder (readFromFolder) or the plugin cache (installPath).
  mapfile -t roots < <(claude plugin list --json | jq -r --arg id "${PLUGIN_NAME}@${PLUGIN_NAME}" \
    '.[] | select(.id == $id) | .readFromFolder, .installPath | values' | sort -u)
  [[ "${#roots[@]}" -gt 0 ]] || {
    log_error "claude does not report where ${PLUGIN_NAME} is installed."
    return 1
  }
  override_permissions claude "$dist" "$CLAUDE_SETTINGS" "${roots[@]}"
}

mapfile -t providers < <(resolve_providers)
[[ "${#providers[@]}" -gt 0 ]] || {
  log_error "No supported agent (agy, claude) found."
  exit 1
}

for provider in "${providers[@]}"; do
  dist=$(fetch_dist "$provider")
  [[ -d "$dist" ]] || {
    log_error "No compiled ${provider} plugin at ${dist}"
    exit 1
  }
  "install_${provider}" "$dist"
done

log_info "Done."
