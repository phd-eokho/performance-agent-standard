# Plugin Verification History && Confirmed Details

Section: Antigravity Plugin Design
Req: Prevent misconfiguration of Antigravity plugins && hooks.
- Rule: Plugin Directory Placement: Antigravity plugins MUST be installed to `~/.gemini/config/plugins/` (NOT `~/.gemini/antigravity-cli/plugins/`). This was a historical failure point where plugins were placed in the wrong path.
- Rule: Hooks Visibility: Plugin-defined hooks do NOT appear in the `/hooks` TUI command. The `/hooks` UI only shows project-local && global user hooks. Plugin hooks are still evaluated actively at runtime despite being hidden from the UI.
- Rule: Validation Gate: Run `agy plugin validate <dir> --strict` on every compiled plugin; the loader silently skips invalid rules && hook files. (Verified agy 1.4.6, 2026-10-31)
- Rule: Rule Location: Rules load ONLY from a flat `rules/` directory; files in `rules/<subdir>/` && a plugin-root `AGENTS.md` are never loaded. `rules/AGENTS.md` loads without frontmatter (core always-on file).
- Rule: Rule Frontmatter: `trigger` MUST be one of `always_on`, `glob`, `model_decision`, `manual`; `globs` MUST be a single comma-separated string (YAML lists fail to parse && the rule is skipped). `alwaysApply` is NOT recognized.
- Rule: Hook File Format: `hooks.json` top-level keys are hook names, each mapping events → entries: `{"<name>": {"PreToolUse": [{"matcher": "...", "hooks": [{"command": "..."}]}]}}`. `SessionStart` entries are flat: `[{"command": "..."}]`. A Claude-style top-level `"hooks"` wrapper loads as one hook literally named `hooks`.
- Rule: Hook Events: Supported events are `SessionStart`, `PreInvocation`, `PostInvocation`, `Stop`, `PreToolUse`, `PostToolUse`; `SessionEnd` is ignored.
- Rule: Hook Working Directory: Hook commands run with the plugin folder as cwd; `${PLUGIN_ROOT}` is NOT set. Use relative `./scripts/...` paths && read the workspace path from the hook payload.

Section: Claude Code Plugin Verification
Req: Ensure Claude Code hooks trigger correctly for file modifications.
- Rule: Hook Lifecycle: Claude Code natively supports `PreToolUse` && `PostToolUse` lifecycle events within `.claude/settings.json`.
- Rule: Hook Matchers: Claude Code uses `Edit` && `Write` as the internal matcher names for file operations. Use a regex matcher like `Write|Edit` to reliably intercept file changes.
