---
---

# `build-permission` Skill

Section: Architecture & Layers
Req: Layer Segregation: Categorize commands strictly by their state mutation boundaries.
- Rule: Allow Layer: Enforce this layer exclusively for read-only operations and isolated actions that do not alter the user's primary working directory state.
- Rule: Sandbox Allow Layer: Enforce this layer for file mutations (writing/editing) that are strictly visible and easily revertible via repository status tracking.
- Rule: Ask Layer: Enforce this layer for operations that traverse the repository tree, obscure uncommitted work, alter remote states, or persist untrackable changes across mounted boundaries.
- Rule: Deny Layer: Enforce this layer exclusively for irreversibly destructive commands.

Section: Mutually Exclusive Pattern
Req: Unambiguous Compilation: Prevent rule overlap to guarantee strict execution layers.
- Rule: Auto-Wildcard Isolation: For commands where the base prefix and all subcommands inherently share the same layer boundary, exclusively register the base prefix. The compiler will natively expand it to match all arguments.
- Rule: Explicit Subcommand Segregation: For commands containing subcommands distributed across multiple layers, explicitly register the full subcommand strings and absolutely avoid registering the base prefix to prevent false-positive wildcard expansion.

Section: Compilation Logic
Req: Optimized Rule Generation: Compile patterns efficiently while maintaining execution security.
- Rule: Native Clean Prefix: The compiler MUST output clean beginning command prefixes and compressed character tries without artificial regex prefix anchors (such as `^` or `(?:^|\s)`) or suffix regex matchers. Agent platform engines evaluate commands natively from invocation start.
- Rule: Character Compression: The compiler MUST dynamically generate character-level shared prefixes using a trie algorithm for commands sharing a base executable to optimize evaluation performance.
- Rule: Defense-in-Depth Layering: Security against destructive operations or dangerous command pipelines MUST be enforced through `PreToolUse` lifecycle hook guards (e.g., `bash-guard.sh`) and explicit `deny` layer precedence, maintaining clean, human-readable configurations in `settings.json`.
- Rule: Cross-Provider Compatibility: The compiler MUST map outputs natively, generating clean prefix directives for Antigravity (`command(...)`), while generating beginning-anchored Bash Globs (`Bash(cmd)`, `Bash(cmd *)`) for Claude Code.

Section: Usage
Req: Standardized Deployment: Provide uniform execution targets for agent integration.
- Rule: JSON Block Generation: Execute `python3 {{SKILL_DIR}}/scripts/compiler.py --source {{SKILL_DIR}}/whitelist.json --provider <provider_name>` (`antigravity` or `claude`) to generate the raw JSON configuration block for that specific platform.
- Rule: Agent-Driven Merging: The compiler MUST NOT overwrite user configuration files directly. The executing AI agent MUST capture the JSON output, evaluate it against existing user settings (e.g. keeping existing manual additions untouched), and use its own file-editing tools to surgically merge the new rules into the global or local `settings.json`.
