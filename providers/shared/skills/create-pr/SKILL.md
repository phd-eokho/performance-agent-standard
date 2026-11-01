---
---

# Create Pull Request Skill

Def: Purpose → Create a pull request from HEAD to target branch programmatically, handling detached HEAD and generating optimized descriptions.

Section: Invocation Parameters

- `[target]`: Optional. Target branch to compare and open the PR against. Defaults to the repository's default branch.
- `[draft/ready]`: Optional. PR status. Defaults to `draft`.
- `[language]`: Optional. Target language for the PR title and description. Defaults to Korean (한국어).
- Rule: All parameters are optional and order-free; classify each given value by form, not position: `draft`/`ready` → `[draft/ready]`; a natural-language name (e.g., `english`, `한국어`) → `[language]`; any other value → `[target]`.

Section: Execution Flow

Step: 1. Pre-flight Validation:
- Run `{{SKILL_DIR}}/scripts/pre-pr-check.sh [target]` (pass `[target]` only if specified).
- Rule: Agent MUST NOT run any manual git/gh inspection commands (e.g., `git log`, `git diff`, `git branch`, `gh repo view`). Rely entirely on `pre-pr-check.sh` for all environment and context data.
- Rule: If script exits non-zero → display stderr, suggest action, and stop.
- Parse stdout as `KEY=value` pairs: `TARGET_BRANCH`, `RESOLVED_TARGET`, `CURRENT_BRANCH`, `IS_DETACHED`, `MATCHED_PR`, `IS_TRIVIAL`, `COMMITS_FILE`, `DIFF_FILE`, `DIFF_LINES`.

Step: 2. Branch Checkout (if detached):
- If `IS_DETACHED=true`: generate a short descriptive branch name from `COMMITS_FILE` content.
- Format: If no workspace-specific branch naming rule exists, use conventional categorization prefixes (e.g., `feat/<name>`, `fix/<name>`, `docs/<name>`, `chore/<name>`).
- Rule: Always prioritize and respect any workspace-specific branch naming conventions if they exist.
- Rule: Execute `git checkout -b <branch-name>` immediately. Update `CURRENT_BRANCH` to the new name.

Step: 3. Remote Push:
- Rule: Execute `git push -u origin <CURRENT_BRANCH>`.

Step: 4. PR Message Generation:
- Read `COMMITS_FILE` and `DIFF_FILE` (paths provided by `pre-pr-check.sh` output). Do NOT run any git commands to re-collect this data.
- Evaluate whether commit messages are comprehensive (subject + explanatory body).
- Rule: If comprehensive AND `IS_TRIVIAL=true` → derive PR title and description from commits only.
- Rule: Otherwise (NOT comprehensive OR `IS_TRIVIAL=false`) → derive PR title and description from `DIFF_FILE`.
- Format: If no workspace-specific PR template is provided, follow this structured format:
  1. **Summary**: Explain what the changes are, what they affect, and what they mean for the project. (MUST use full-sentence prose format)
  2. **Concerns**: Note potential risks, regressions, or areas requiring careful review. (Choose the format—such as an itemized list with prose explanations—that best explains the specific concern points)
  3. **Key Changes**: Provide a bulleted list of the most significant code changes. (MUST use an itemized, concise fragment format)
- Rule: Always prioritize and respect any workspace-specific PR template if one exists. Fall back to the structured format above only if no template is found.
- Language: Generate in `[language]` (default Korean).

Step: 5. PR Creation or Update:
- Rule: Write the generated body to a temp file first; never pass a multi-line body inline.
- Rule: If `MATCHED_PR` exists, update it via `gh pr edit <MATCHED_PR> --title "<title>" --body-file <body-file>`; otherwise, create a new PR via `gh pr create --base <TARGET_BRANCH> --head <CURRENT_BRANCH> --title "<title>" --body-file <body-file>`.
- Flag: When creating a new PR, append `--draft` unless `[draft/ready]` is explicitly `ready`.
