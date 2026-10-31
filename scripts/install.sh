#!/usr/bin/env bash
# ---
# purpose: Installs the plugin through each agent's own plugin manager; every installed file stays inside the plugin directory.
# ---
#   antigravity: agy plugin install            → ~/.gemini/config/plugins/performance-agent-standards/
#   claude:      local marketplace + install   → ~/.claude/plugins/performance-agent-standards/ (+ Claude's plugin cache)
# Global files (CLAUDE.md, GEMINI.md, rules/, settings.json, skills/) are never modified.

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
REPO_SLUG=${REPO_SLUG:-"DeokhoKim/performance-agent-standard"}
PROVIDER=${PROVIDER:-auto}
SOURCE_DIR=${SOURCE_DIR:-}
CLAUDE_MARKETPLACE_DIR=${CLAUDE_MARKETPLACE_DIR:-"$HOME/.claude/plugins/${PLUGIN_NAME}"}

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

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

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

install_antigravity() {
  local dist="$1"
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
}

install_claude() {
  local dist="$1"
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

log_info "Done. Remove files left by pre-plugin versions with: scripts/migrate-legacy.sh"
