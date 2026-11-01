---
---

# Staged Commit Skill

Def: Purpose → Generate comprehensive commit message for staged changes, then commit immediately.

Section: Invocation Parameters

- `[language]`: Optional. Target language for the commit message. Defaults to Korean (한국어).

Section: Execution Flow

Step: 1. Pre-flight Validation:
- Run the pre-commit script `{{SKILL_DIR}}/scripts/pre-commit-check.sh`.
- Rule: Agent MUST NOT perform manual check commands (e.g., `git status`, `git diff`). Rely entirely on `pre-commit-check.sh`.
- Rule: If `pre-commit-check.sh` fails (exit status > 0) → display output, suggest action, and stop execution immediately.
- Parse stdout as `KEY=value` pairs: `STAGED_COUNT`, `STAGED_LINES`, `DIFF_FILE`.

Step: 2. Context Collection:
- Rule: Read the temp file at the `DIFF_FILE` path output by `pre-commit-check.sh` as the sole diff context. Do NOT run any additional git commands.
- Rule: `git commit` always applies staged changes to the current HEAD regardless of branch state (attached or detached). No branch comparison is needed or performed.

Step: 3. Commit Message Generation:
- Format: Conventional Commits (`<type>(<scope>): <subject>` + body).
- Language: Use `[language]` if specified, otherwise default to Korean (한국어).
- Subject: Max 50 chars, imperative mood, no trailing period.
- Body: Wrapped at 72 chars. Prioritize any workspace-specific or injected format if it exists; otherwise, follow this structured format:
  1. **Summary**: Provide a full-sentence prose overview explaining what this commit means and its overall impact before detailing the changes.
  2. **Detailed Changes**: Provide a bulleted list of the specific code changes. MUST use an itemized, concise fragment format (e.g., bulleted short phrases, noun-endings).
  3. **Affected Areas**: Note which features, modules, or flows will be affected by these changes.

Step: 4. Execution:
- Rule: Execute the commit immediately; no user confirmation required. Pass the multi-line message via a quoted heredoc (`git commit -F - <<'EOF'`), never a multi-line `-m`.
  - Exception: If the commit fails due to pre-commit hook fixes, the agent may run `git add` ONLY on already-staged files to update their index state, then retry the commit once. No other files can be added.
