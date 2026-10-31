# Agent Standards

Project instructions override these rules. Among these rules, the one for the narrower file scope wins: language over native, native over general code.

## Approach
- Favor caution over speed; skip deliberation only for provably trivial tasks.
- State assumptions before acting; ask when the request is ambiguous or contradicts the code. For questions or open requests, propose a plan instead of executing.
- Write the minimum code for the request: no speculative features, options, layers, or files.
- Change only what the task needs; match existing style and naming; remove only dead code your change created.
- Reuse in this order: existing code > standard library > platform feature > installed dependency > new code. Add dependencies only with approval.
- Design deep modules: small stable interface, hidden implementation. If changing an internal detail would force callers to change, redesign the interface.
- Inline wrappers that add no behavior; introduce an abstraction at the second implementation, not the first.
- Remove code smells (coupling, leaky abstraction, dead code, primitive obsession) in code you write or modify.
- Define the done-check first; verify with the narrowest existing check (test, build, lint) before reporting. Do not create a test suite where none exists; skip runtime checks for doc-only changes.

## Context
- Read only what the task needs: locate with a scoped search (path plus extension or symbol), then read the relevant line range.
- Do not read `.env`, lockfiles, build outputs, or test fixtures unless the task is about them.
- Ask for a path that cannot be identified from the request instead of scanning the filesystem.
- Map cross-file dependencies first, then make related edits in one batch with targeted edit tools instead of rewriting files.
- Delegate broad exploration or large log parsing to a subagent that returns only a summary; edit single files directly.

## Execution
- Use the project toolchain: `.venv` or `uv run` for Python; local `CC`/`CXX`, CMake, or Makefile for C/C++; `Cargo.toml`, `package.json`, `go.mod` over global tools. Read `README.md` once only when no toolchain config exists.
- Inline automation: shell pipelines (`grep`, `awk`, `sed`, `jq`, `xargs`) first, with `set -euo pipefail`, `printf`, and inline failure checks; Python only for logic unreadable in shell, standard library only unless a local env or a PEP 723 `uv run` script supplies packages.
- Reply with the result first; no preamble or filler.
