#!/usr/bin/env bash
# ---
# purpose: Compiles shared rules, hooks, and skills into self-contained plugin directories (dist/antigravity, dist/claude).
# ---

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

BASE_DIR=${BASE_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}
DIST_DIR=${DIST_DIR:-"${BASE_DIR}/dist"}
PLUGIN_NAME="performance-agent-standards"
SHARED_DIR="${BASE_DIR}/providers/shared"

VERSION=$(sed -n 's/^version = "\(.*\)"/\1/p' "${BASE_DIR}/pyproject.toml")
[[ -n "$VERSION" ]] || {
  log_error "version not found in pyproject.toml"
  exit 1
}

CODE_GLOBS="**/*.rs, **/*.c, **/*.cc, **/*.cpp, **/*.cxx, **/*.h, **/*.hpp, **/*.hxx, **/*.zig, **/*.py, **/*.sh, **/*.bash"
NATIVE_GLOBS="**/*.rs, **/*.c, **/*.cc, **/*.cpp, **/*.cxx, **/*.h, **/*.hpp, **/*.hxx, **/*.zig"
CPP_GLOBS="**/*.cc, **/*.cpp, **/*.cxx, **/*.h, **/*.hpp, **/*.hxx"

# Rule registry: "<name>|<globs>|<description>". Output: rules/<name>.md. Precedence comes from scope (AGENTS.md), not from names or order.
# The core file (providers/shared/AGENTS.md) is always on; every registry rule is glob-triggered.
RULES=(
  "markdown|**/*.md, **/*.mdc|Markdown writing: preserve meaning, no filler, structure over prose."
  "code|${CODE_GLOBS}|General code design, trust-boundary safety, scoped resources, pipelines, comments."
  "native|${NATIVE_GLOBS}|Native code: naming, memory layout, zero-copy hardware buffers, bit and data locality, ABI, static lifetime."
  "rust|**/*.rs|Rust ownership, layout, arithmetic, concurrency, dispatch, errors, and build profile."
  "cpp|${CPP_GLOBS}|C++ lifetime, types, parameters, translation units, and per-standard (17/20/23) idioms."
  "bash|**/*.sh, **/*.bash|Bash safety, inline checks, trap cleanup, and the standard log functions."
  "python|**/*.py|Python typing, dataclasses, idioms, resources, concurrency, and NumPy/Numba usage."
)

# Writes one rule with agy frontmatter (also read by inject-rules.sh on Claude Code).
# agy: trigger is an enum and globs must be one comma-separated string (lists are rejected).
emit_rule() {
  local globs="$1" desc="$2" src="$3"
  printf -- '---\ntrigger: glob\nglobs: "%s"\ndescription: "%s"\n---\n\n' "$globs" "${desc//\"/\\\"}"
  cat "$src"
}

# Copies skills, assembling frontmatter and resolving {{SKILL_DIR}} / {{RULES_DIR}} to absolute references
# (skill commands run from the user's workspace, never from the plugin folder).
# Arguments: provider, output skills dir, skill dir reference (may contain <name>), rules dir reference
compile_skills() {
  local provider="$1" dest_root="$2" skill_ref="$3" rules_ref="$4"
  local skill_dir name dest
  for skill_dir in "${SHARED_DIR}"/skills/*/; do
    skill_dir="${skill_dir%/}"
    name="${skill_dir##*/}"
    dest="${dest_root}/${name}"
    mkdir -p "$dest"
    {
      printf -- "---\n"
      cat "${skill_dir}/frontmatter.yaml"
      [[ -f "${skill_dir}/frontmatter.${provider}.yaml" ]] && cat "${skill_dir}/frontmatter.${provider}.yaml"
      printf -- "---\n\n"
      awk 'c >= 2 && (NF || seen) {seen = 1; print} /^---$/ && c < 2 {c++}' "${skill_dir}/SKILL.md"
    } | sed "s|{{SKILL_DIR}}|${skill_ref//<name>/$name}|g; s|{{RULES_DIR}}|${rules_ref}|g" > "${dest}/SKILL.md"
    # Non-ignored files only, so local artifacts (.venv, __pycache__) never ship.
    git -C "$skill_dir" ls-files -co --exclude-standard -z -- . ':!SKILL.md' ':!frontmatter*' |
      tar -C "$skill_dir" --null -T - -cf - | tar -xf - -C "$dest"
  done
}

# Fails the build on anything that would make an agent search for files instead of reading a direct path.
lint_plugin() {
  local out="$1" rules_dir="$1/rules" skills_dir="$2" failed=0 ref names
  names=$(printf '%s\n' "${RULES[@]%%|*}" AGENTS | paste -sd '|')

  # Rules are delivered by the platform; they must never point at other rule files or tool names.
  if grep -nE "@\\[|\\]\\([^)]*\\.md\\)|\\b(${names})\\.md\\b|\\{\\{|grep_search|find_by_name|view_file" "${rules_dir}"/*.md; then
    log_error "rules contain cross-references, placeholders, or tool names"
    failed=1
  fi
  grep -rn '{{' "$skills_dir" --include=SKILL.md && {
    log_error "unresolved skill placeholder"
    failed=1
  }
  # Every rule file a skill names must exist in the plugin.
  while IFS= read -r ref; do
    [[ -f "${rules_dir}/${ref}" ]] || {
      log_error "skill references missing rule: ${ref}"
      failed=1
    }
  done < <(grep -rhoE 'rules/[A-Za-z-]+\.md' "$skills_dir" | sed 's|^rules/||' | sort -u)
  [[ "$failed" -eq 0 ]] || exit 1
}

# Arguments: provider
compile_provider() {
  local provider="$1"
  local out="${DIST_DIR}/${provider}" src="${BASE_DIR}/providers/${provider}"
  local entry name globs desc

  log_info "Compiling ${provider}..."
  mkdir -p "${out}/rules" "${out}/scripts"

  # Rules (flat directory: agy ignores subdirectories). Core loads without frontmatter as rules/AGENTS.md.
  cp "${SHARED_DIR}/AGENTS.md" "${out}/rules/AGENTS.md"
  for entry in "${RULES[@]}"; do
    IFS='|' read -r name globs desc <<< "$entry"
    emit_rule "$globs" "$desc" "${SHARED_DIR}/rules/${name}.md" > "${out}/rules/${name}.md"
  done

  cp -r "${BASE_DIR}/scripts/hooks" "${out}/scripts/"
  find "${out}/scripts" -name '*.sh' -exec chmod +x {} +

  case "$provider" in
    antigravity)
      # Hooks run with the plugin folder as cwd, so hooks.json keeps relative ./scripts paths.
      cp "${src}/hooks.json" "${out}/hooks.json"
      sed "s/__VERSION__/${VERSION}/g" "${src}/plugin.json" > "${out}/plugin.json"
      local root="\$HOME/.gemini/config/plugins/${PLUGIN_NAME}"
      compile_skills "$provider" "${out}/skills" "${root}/skills/<name>" "${root}/rules"
      ;;
    claude)
      mkdir -p "${out}/.claude-plugin" "${out}/hooks"
      cp "${src}/hooks.json" "${out}/hooks/hooks.json"
      sed "s/__VERSION__/${VERSION}/g" "${src}/plugin.json" > "${out}/.claude-plugin/plugin.json"
      # Single-plugin marketplace so the directory installs with `claude plugin marketplace add <dir>`.
      jq -n --arg n "$PLUGIN_NAME" --arg v "$VERSION" \
        '{name: $n, owner: {name: "DeokhoKim"}, plugins: [{name: $n, source: "./", version: $v,
          description: "Performance-oriented coding standards, safety guard hooks, and review skills."}]}' \
        > "${out}/.claude-plugin/marketplace.json"
      compile_skills "$provider" "${out}/skills" "\${CLAUDE_SKILL_DIR}" "\${CLAUDE_SKILL_DIR}/../../rules"
      ;;
  esac

  lint_plugin "$out" "${out}/skills"
}

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
compile_provider antigravity
compile_provider claude

if command -v agy &> /dev/null; then
  agy plugin validate "${DIST_DIR}/antigravity" --strict > /dev/null 2>&1 ||
    {
      agy plugin validate "${DIST_DIR}/antigravity" --strict >&2 || true
      log_error "agy plugin validation failed"
      exit 1
    }
  log_info "agy plugin validation passed"
else
  log_warn "agy not found; skipped agy plugin validation"
fi
if command -v claude &> /dev/null; then
  claude plugin validate "${DIST_DIR}/claude" > /dev/null 2>&1 ||
    {
      claude plugin validate "${DIST_DIR}/claude" >&2 || true
      log_error "claude plugin validation failed"
      exit 1
    }
  log_info "claude plugin validation passed"
else
  log_warn "claude not found; skipped claude plugin validation"
fi

log_info "Compilation complete: ${DIST_DIR}"
