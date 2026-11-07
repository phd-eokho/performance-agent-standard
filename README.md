# Performance Agent Standards Plugin

Coding standards, safety guard hooks, and review skills for Google Antigravity (`agy`, primary target) and Claude Code.

Design invariants:
- **Isolated install**: every file lives inside the plugin directory. Global `CLAUDE.md`, `GEMINI.md`, `rules/`, and `skills/` are never touched; in `settings.json` the installer replaces only the permission rules (see [Permissions](#permissions)).
- **Platform-loaded rules**: the agent never has to find a rule. agy loads rules by trigger; on Claude Code a hook delivers them. Rules never reference other rule files.
- **Install-location independent skills**: review skills carry their standards inline; skills reach their own scripts through Claude's `${CLAUDE_SKILL_DIR}` or, on agy, the plugin folder taken from the loaded `rules/AGENTS.md` path. No skill names an install path.
- **Hook or rule**: mechanical, judgment-free work that would cost tokens on every repetition is a hook; work that needs judgment is a (cached) rule.
- **Linux and macOS only** (POSIX shell, `jq` required).

---

## User Guide

### Install

```bash
curl -sSfL https://raw.githubusercontent.com/DeokhoKim/performance-agent-standard/main/scripts/install.sh | bash
```

- Installs for every detected agent; restrict with `--provider antigravity` or `--provider claude`.
- From a local checkout: `scripts/install.sh --source .`

| Agent | Mechanism | Location |
|---|---|---|
| agy | `agy plugin install` | `~/.gemini/config/plugins/performance-agent-standards/` |
| Claude Code | local marketplace + `claude plugin install` | `~/.claude/plugins/performance-agent-standards/` (+ Claude's plugin cache) |

The installer also replaces `permissions.allow`, `ask`, and `deny` in `~/.gemini/antigravity-cli/settings.json` (agy) and `~/.claude/settings.json` (Claude Code, or `$CLAUDE_CONFIG_DIR/settings.json`) with the compiled policy. Other settings are kept, and the previous file is saved as `settings.json.<timestamp>.bak`. Override the targets with `AGY_SETTINGS` and `CLAUDE_SETTINGS`.

### Rules

| File | Loaded | Content |
|---|---|---|
| `rules/AGENTS.md` | always | Approach, context discipline, toolchain and inline execution |
| `rules/markdown.md` | `**/*.md` | Documentation writing |
| `rules/code.md` | source files | Design, trust-boundary safety, scoped resources, pipelines, comments |
| `rules/native.md` | C, C++, Rust, Zig | Naming, memory layout, zero-copy hardware buffers, bits and locality, ABI, static lifetime |
| `rules/rust.md` | `**/*.rs` | Ownership, layout, arithmetic, concurrency, dispatch, errors, build profile |
| `rules/cpp.md` | C++ files | Lifetime, types, parameters, translation units, C++17/20/23 table |
| `rules/bash.md` | `**/*.sh` | Strict mode, inline checks, trap cleanup, standard log functions |
| `rules/python.md` | `**/*.py` | Typing, dataclasses, idioms, resources, concurrency, NumPy/Numba |

Precedence follows scope, not file names: a language rule overrides `native.md`, which overrides `code.md`.

Where each pre-refactor rule went: [`docs/rule-coverage.md`](docs/rule-coverage.md).

### Hooks (`scripts/hooks/`)

| Hook | Event | Behavior |
|---|---|---|
| `pre-tool/file-guard.sh` | before file writes | Blocks edits to secrets/keys, `.env*` (templates allowed), `*.tfstate`, lockfiles, `.git/` |
| `pre-tool/bash-guard.sh` | before shell commands | Blocks root/home/wildcard `rm -rf`, `sed -i`/`perl -i`/`ed`, mutating `gh api`/`gh repo delete`, disk utilities, `sudo`, `chmod -R 777`, fork bombs |
| `pre-tool/git-guard.sh` | before shell commands | Blocks force push, `reset --hard/--merge`, `clean -f`, `branch -D`, `checkout/restore .`, `stash drop/clear`, `--no-verify`/`commit -n` |
| `post-tool/validate-format.sh` | after file writes | Runs the repository's `prek` checks on the edited file and reports failures to the agent |
| `session/inject-rules.sh` | Claude Code only: session start, file read/edit | Delivers `AGENTS.md` at session start and each glob rule once per session when a matching file is touched; resets after compaction |
| `session/cleanup-session.sh` | agy session start, Claude session end | Removes per-session hook state and sweeps state older than 24 hours |
| `lib.sh` | (shared) | Payload parsing for both agents and the hook response format |

Guards match per command segment (`|`, `;`, `&&` boundaries), so text such as `git commit -m "re-run tests"` is not misread as a flag.

### Permissions

`scripts/permissions/policy.json` is the read-only boundary: an allowed command never changes the remote and never makes a local change that could later reach it. Downloads count as reads (`git fetch`, `git clone`, `gh repo clone`, `gh release download`), since they only copy remote content into local files or remote-tracking refs. Each group lists command prefixes, the options or subcommands that cross the boundary (writing files, refs, or configuration, moving local branches, running programs; from each command's `--help`), and the evidence (`why`).

| Rule | agy | Claude Code |
|---|---|---|
| Read-only prefix | `command(git log)` allows | no rule when Claude Code classifies the command itself (`claude_builtin`); otherwise `Bash(<prefix>)`, `Bash(<prefix> *)` |
| Write option anywhere | one `command(regex:...)` ask per argument position below `max_args`, plus a cap that asks for any longer command | `Bash(<prefix> * <option>*)` ask |
| Denied option anywhere (`--upload-pack`) | asks like a write option: agy ignores regex rules in `deny` | `Bash(<prefix> * <option>*)` deny |
| Flags passed on after `--` (`gh repo clone -- <git clone flags>`) | the target command's asks and denies, at every position after `--` | `Bash(<prefix> * -- * <option>*)` deny |
| Not in the policy | asks (default) | asks (default) |

On Claude Code, `git fetch` and the clone commands still ask (`--upload-pack` is denied): their carve-outs include bundled short flags (`-tf`, `-qc`), which Claude globs cannot express. Write commands outside the policy (`git commit`, `rm`, `npm test`) get no rule, so the agent's default prompt applies and an "always allow" choice still takes effect. Writing to a file with `>` is checked by the agent itself.

---

## Developer Guide

```text
providers/
├── shared/
│   ├── AGENTS.md          # core rules (always on)
│   ├── rules/*.md         # glob-scoped rules (registry in scripts/compile.sh)
│   └── skills/*/          # SKILL.md ({{SKILL_DIR}}, {{RULE:<name>}}) + frontmatter.yaml + frontmatter.<provider>.yaml
├── antigravity/           # hooks.json (named hooks), plugin.json
└── claude/                # hooks.json, plugin.json
scripts/
├── compile.sh             # builds dist/antigravity and dist/claude (+ permissions.json), lints, validates
├── install.sh             # installs through agy / claude plugin managers, replaces permission rules
├── permissions/           # policy.json (read-only boundary) + compile.sh (per-agent rules)
└── hooks/                 # hook scripts (see table above)
tests/
├── hooks/                 # guard fixtures: cases.tsv + run.sh
├── permissions/           # boundary cases: cases.tsv + run.py (matches compiled rules like each agent)
└── eval/                  # agy behavior evals: cases/*/{prompt.txt,fixture/,check.sh} + run.sh
docs/
└── rule-coverage.md   # old rule → new location
```

### Build and test

```bash
scripts/compile.sh       # fails on rule cross-references, unresolved placeholders, install paths in skills, or plugin validation errors
tests/hooks/run.sh       # guard hook fixtures
python3 tests/permissions/run.py   # permission boundary cases against the compiled rules
tests/eval/run.sh --baseline   # agy flash: pass rate with vs. without the plugin, per rule
```

`tests/eval/run.sh` needs the plugin installed (`scripts/install.sh --provider antigravity --source .`). It runs `agy -p` sandboxed with file edits auto-approved; commands follow the installed permission rules, the same in both runs. A case also fails when the agent searched for rule files. Verdicts: `keep`, `not followed: sharpen the rule`, or `no effect: delete or rewrite`.

### Package releases

```bash
(cd dist/antigravity && zip -r ../../performance-agent-standards-antigravity.zip .)
(cd dist/claude && zip -r ../../performance-agent-standards-claude.zip .)
```

### Local setup

```bash
uv sync                       # installs prek (pre-commit runner) into .venv
.venv/bin/prek run --all-files
```

---

## References & Acknowledgements

- **Andrej Karpathy's engineering guidelines**: the Approach section of `providers/shared/AGENTS.md` (think before coding, simplicity first, surgical changes, goal-driven execution) derives from [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills).
- **Boucle framework**: `bash-guard` and `git-guard` are inspired by [Bande-a-Bonnot/Boucle-framework](https://github.com/Bande-a-Bonnot/Boucle-framework).
- **Ponytail**: minimalist engineering instincts are inspired by [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail).
- **Platforms**: [Google Antigravity](https://antigravity.google/) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code).
