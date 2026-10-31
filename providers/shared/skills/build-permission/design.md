# Permission Architecture & Design Considerations

This document serves as the foundational design reasoning behind the `build-permission` skill. Because `SKILL.md` strictly enforces concise rules over narrative explanation, this supplement captures the context, security constraints, and platform quirks that shaped the skill's architecture.

## 1. The Four-Layer Trust Model
The permission configuration is deeply tied to how operations impact the host filesystem and git repository state.

### Allow (Inherently Safe)
Reserved exclusively for read-only operations (e.g., `git log`, `cat`, `gh issue list`) and purely isolated workspace commands (`git clone`, `git worktree`). These commands cannot negatively impact the active branch or destroy data.

### Sandbox Allow (Trackable File Mutations)
Many agents operate within lightweight jails (e.g., Bubblewrap, nsjail) that prevent host escalation.
- **The Rationale**: If a command mutates files within the workspace (e.g., `eslint --fix`, `npm run build`), it is allowed autonomously *only if* the changes can be trivially tracked and reverted using `git status`.
- **The Benefit**: It eliminates prompt fatigue for routine formatting and test-running.

### Ask (Untrackable or Tree-Modifying)
Explicit user authorization is mandated for commands that obscure state or bypass the sandbox isolation.
- **Git Tree Modifiers**: Commands like `git commit`, `git checkout`, and `git reset` move HEAD. The agent must never autonomously alter the tree state without the user knowing.
- **Mounted Bleeding (The `npm install` problem)**: If an agent writes ignored directories (`node_modules`) or modifies configurations (`.git/config`), these changes bypass `git status`. If the workspace is volume-mounted from the host OS, these changes permanently bleed onto the host system untracked. They MUST require authorization.

### Deny (Catastrophic)
Strictly blocks `rm -rf /`, `mkfs`, and destructive `chmod` commands. Note that standard `git push --force` or specific file `rm` commands belong in `Ask`, as they are occasionally necessary.

## 2. Native Clean Prefix & Defense-in-Depth
AI agent CLI platforms evaluate tool execution configurations by inspecting the command invocation starting from its base command.

### The Native Clean Prefix Model
Rather than injecting complex, fragile regex suffix constraints (such as `(?:\s+[^|&;]*)?$`) that break on valid quoted arguments (e.g., `-F';'`, `&` in query strings), the compiler generates **native clean prefixes** and compressed tries:
1. **Natural Beginning-Command Anchoring**: Command patterns begin directly with the executable command itself (e.g., `command(cat)`, `command(git status)`). No artificial prefix regex tokens (`^` or `(?:^|\s)`) or unanchored prefix globs (`Bash(* cmd *)`) are generated.
2. **Defense-in-Depth with Lifecycle Hooks**: Dangerous shell patterns (such as `rm -rf /`, `curl | bash`, or destructive command chaining) are intercepted comprehensively by `PreToolUse` lifecycle hooks (`bash-guard.sh` and `git-guard.sh`). This keeps `settings.json` clean, readable in TUI editors (`/permissions`, `/config`), and fully compliant with official platform schemas.
3. **Precedence Hierarchy**: The strict **Deny > Ask > Allow** precedence guarantees that any blocked pattern in the `deny` list immediately takes priority over allowed prefixes.

## 3. Provider-Specific Compilation Nuances
The compiler natively accommodates the parsing engines of four different agent platforms.

- **Antigravity**: Utilizes clean `command(prefix)` and compressed token tries (e.g., `command(git (?:branch|log))`).
- **Claude Code**: The native `permissions.allow/deny/ask` arrays strictly utilize beginning-anchored **Bash Globs** (e.g., `Bash(git status)`, `Bash(git status *)`), omitting unanchored prefix wildcards (`* cmd`).

## 4. The Mutually Exclusive JSON Pattern
To prevent false-positive matches across layers, `whitelist.json` must be curated using the "Mutually Exclusive Pattern."
- If *all* options for a tool (e.g., `git diff`) belong in `Allow`, only the base prefix `"git diff"` is written. The compiler auto-expands it.
- If options straddle layers (e.g., `git stash list` [Allow] vs `git stash pop` [Ask], or `git config --get` [Allow] vs `git config --set` [Ask]), they MUST be written out fully as specific subcommands. Writing bare `"git stash"` or `"git config"` in Allow or Ask would cause a wildcard collision, falsely expanding over subcommands in other layers.
