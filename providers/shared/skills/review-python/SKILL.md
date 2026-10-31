---
---

# Python Code Review

Arguments: `[target]` (optional) is a file, directory, or git diff range; default is uncommitted changes.

1. Read these standards, general to specific (a narrower-scope file overrides a broader one):
   - `{{RULES_DIR}}/code.md`
   - `{{RULES_DIR}}/python.md`
2. Resolve targets from `[target]` (or uncommitted git changes) and keep only `*.py` files.
3. Report:
   1. **Summary**: overall conformance.
   2. **Violations**: each with `path:line`, the violated standard line, and why it matters here.
   3. **Simplifications**: tag each `delete:` (dead code), `stdlib:` (dependency replaceable by the standard library), `native:` (library replaceable by a platform built-in), `yagni:` (speculative abstraction or single-caller wrapper), or `shrink:` (logic expressible with simpler primitives); end with `net: -N lines, -M deps` or `Lean already.`
   4. **Fixes**: minimal, copy-paste-ready snippets. Skip style preferences the standards do not cover.
