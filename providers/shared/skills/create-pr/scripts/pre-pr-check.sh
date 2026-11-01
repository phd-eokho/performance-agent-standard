#!/usr/bin/env bash
# ---
# purpose: Pre-flight check for create-pr skill. Validates git, remote, gh auth, fetches updates,
#          resolves target branch, and writes commits/diff to temp files for agent consumption.
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

# Temp file registry for cleanup on failure
diff_file=""
commits_file=""
cleanup() {
  [[ -n "$diff_file" && -f "$diff_file" ]] && rm -f "$diff_file"
  [[ -n "$commits_file" && -f "$commits_file" ]] && rm -f "$commits_file"
}
trap cleanup EXIT

# 1. Verify prerequisites
command -v git &> /dev/null || {
  log_error "git command not found."
  exit 1
}
git rev-parse --is-inside-work-tree &> /dev/null || {
  log_error "Not in a git repository."
  exit 1
}
command -v gh &> /dev/null || {
  log_error "gh not found. GitHub CLI is required."
  exit 1
}
gh auth status &> /dev/null || {
  log_error "gh not authenticated. Run 'gh auth login'."
  exit 1
}

# 2. Detect remote (once)
has_remote=$(git remote | head -1)

# 3. Fetch remote updates to surface potential conflicts early
[[ -n "$has_remote" ]] && {
  log_info "Fetching remote updates..."
  git fetch --all --quiet || log_warn "Fetch failed. Proceeding with cached state."
}

# 4. Determine target branch
target_branch="${1:-}"
if [[ -z "$target_branch" ]]; then
  [[ -n "$has_remote" ]] &&
    target_branch=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2> /dev/null || true)
  if [[ -z "$target_branch" ]]; then
    if git show-ref --verify --quiet refs/heads/main; then
      target_branch="main"
    elif git show-ref --verify --quiet refs/heads/master; then
      target_branch="master"
    else
      target_branch="main"
    fi
  fi
fi

# 5. Resolve target to a git ref (freshly fetched remote preferred, local branch fallback)
resolved_target="origin/$target_branch"
if ! git rev-parse --verify --quiet "$resolved_target" &> /dev/null; then
  git rev-parse --verify --quiet "$target_branch" &> /dev/null || {
    log_error "Target branch '$target_branch' could not be resolved on origin or locally."
    exit 1
  }
  resolved_target="$target_branch"
fi

# 6. Ensure HEAD has commits of its own (two-dot: excludes commits only on the target)
commit_count=$(git rev-list "${resolved_target}..HEAD" | wc -l)
[[ "$commit_count" -eq 0 ]] && {
  log_error "No commits between '$resolved_target' and HEAD. Cannot create PR."
  exit 1
}

# 7. Classify git tree: trivial = linear history, no merge commits in range
is_trivial="true"
git merge-base --is-ancestor "$resolved_target" HEAD &> /dev/null || is_trivial="false"
[[ $(git rev-list --merges "${resolved_target}..HEAD" | wc -l) -gt 0 ]] && is_trivial="false"

# 8. Detect detached HEAD
current_branch=$(git symbolic-ref --short -q HEAD 2> /dev/null || true)
is_detached=$([[ -z "$current_branch" ]] && printf 'true' || printf 'false')

# 8.5 Detect matched PR
matched_pr=""
if [[ "$is_detached" == "false" ]]; then
  matched_pr=$(gh pr list --head "$current_branch" --state open --json number --jq '.[0].number' 2> /dev/null || true)
fi

# 9. Write commits and diff to temp files (keeps stdout minimal for token efficiency)
commits_file=$(mktemp /tmp/pr-commits-XXXXXX.txt)
git log --no-merges "${resolved_target}..HEAD" > "$commits_file"

diff_file=$(mktemp /tmp/pr-diff-XXXXXX.patch)
git diff "${resolved_target}...HEAD" > "$diff_file"

diff_lines=$(wc -l < "$diff_file")

# --- Output: minimal KEY=value block, all bulk data in files ---
printf "TARGET_BRANCH=%s\n" "$target_branch"
printf "RESOLVED_TARGET=%s\n" "$resolved_target"
printf "CURRENT_BRANCH=%s\n" "$current_branch"
printf "IS_DETACHED=%s\n" "$is_detached"
printf "MATCHED_PR=%s\n" "$matched_pr"
printf "IS_TRIVIAL=%s\n" "$is_trivial"
printf "COMMITS_FILE=%s\n" "$commits_file"
printf "DIFF_FILE=%s\n" "$diff_file"
printf "DIFF_LINES=%s\n" "$diff_lines"

# Preserve temp files for the agent — disable cleanup trap
trap - EXIT
