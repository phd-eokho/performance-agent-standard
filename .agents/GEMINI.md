# Repository Agent Instructions

## Compatibility
- Every change must work on Antigravity (agy, primary target) and Claude Code.
- Before relying on a frontmatter key, hook event, or platform feature, confirm it in official docs or with `agy plugin validate --strict` / `claude plugin validate`, and record verified facts in `docs/agent-platform-specifics.md`.
- Run `scripts/compile.sh` (lints, then validates both plugins) and `tests/hooks/run.sh` after every change; run `tests/eval/run.sh --baseline` after changing rule wording.

## Plugin layout
- Every installed file lives inside the plugin directory; never write to global `CLAUDE.md`, `GEMINI.md`, `rules/`, `settings.json`, or `skills/`.
- Rules never reference other rule files, tool names, or load orders; the platform loads them by trigger (agy natively, Claude via `inject-rules.sh`).
- Rule files are named by scope (`code.md`, `rust.md`), never numbered; precedence comes from scope (narrower wins), stated once in `AGENTS.md`.
- Skills reference plugin files only through `{{SKILL_DIR}}` and `{{RULES_DIR}}`, which `compile.sh` resolves to absolute paths.

## Hook or rule
- Hook: mechanical work with an obvious, judgment-free procedure that would cost model tokens on every repetition (guards, format checks, rule delivery, state cleanup).
- Rule: work that needs judgment; its static text is cached, so repeated application costs about the same.
- Never use a hook that depends on what is in the model's context (it cannot see it) or that re-sends the same text on every tool call.

## Rule writing
- One bullet = one binding rule: an imperative, plus its condition when it does not always apply (`- Do X when Y; never Z.`).
- No tags (`Section:`, `Req:`, `Rule:`), rule IDs, rationale, or symbolic connectives (`&&`, `||`); use plain words.
- Add an example only when the rule is ambiguous without it; exact templates (log functions, helper macros) are the rule.
- A specific rule extends a general one without repeating it; `AGENTS.md` holds the core, `providers/shared/rules/*.md` hold glob-scoped rules.
- Keep every requirement when rewording; record moves, conditions, and removals in `docs/rule-coverage.md`.

## External dependencies
- At session start, check each source below if `Last Checked` is before today; update the local file only when the source changed after `Last Checked`, then set `Last Checked` to today. Never change the local file's purpose.

| Dependency | Local path | Source | Last Checked |
| :--- | :--- | :--- | :--- |
| Karpathy Guidelines | `providers/shared/AGENTS.md` (Approach) | https://raw.githubusercontent.com/multica-ai/andrej-karpathy-skills/main/skills/karpathy-guidelines/SKILL.md | 2026-08-26 |
| Antigravity Plugin Design | `docs/agent-platform-specifics.md` | Official docs, `agy plugin validate` | 2026-10-31 |
| Claude Plugin Verification | `docs/agent-platform-specifics.md` | Claude Code docs, `claude plugin validate` | 2026-10-31 |
