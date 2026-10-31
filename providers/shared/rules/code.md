# Code

## Design
- Name every algorithmic constant, threshold, and dimension; make it a parameter with a sensible default only when a caller varies it.
- Pass dependencies (config, clients, services) in through constructors or parameters; no hidden globals or hard-coded connections.
- Keep control flow flat: reject edge cases first with guard clauses and early returns, keep the main path unindented, extract each nested branch or loop body into a named function, and split a function instead of passing a flag that switches its behavior.
- Reach SOLID through that arrangement (one job per function, dependencies passed in); never add single-implementation interfaces, factories, or builders.
- Keep related logic in one file until size or domain forces a split.
- Prefer readable names and simple control flow over clever code unless a measurement shows a performance cost.

## Safety
- Validate and sanitize data crossing a trust boundary: API payloads, CLI arguments, environment variables, user input, file paths.
- Use parameterized queries, canonical path resolution, escaped templates, and command execution without shell interpolation of untrusted data.
- Error handling must never corrupt persisted state or lose data.
- Domain math (timing loops, sensor calibration, money) keeps exact precision with explicit tolerances.

## Resources and data
- Release resources and restore state (descriptors, memory, locks, sockets, cwd, environment) through scope-bound mechanisms (RAII, `with`, `defer`, `trap`), never manual cleanup at function end.
- Pass views, slices, or references instead of copies; move ownership of large data; use memory mapping (`mmap`, `memmap2`) or `splice`/`sendfile` for large file and network I/O.

## Concurrency
- Structure parallel work as one-way pipelines connected by channels or pipes; share memory by communicating.
- Where shared state is unavoidable, use atomics with explicit memory ordering instead of ad-hoc locks.

## Comments
- Comment only the non-obvious why: limits, unhandled edge cases, trade-offs, hardware caveats. Never restate the code; no vanity tags.
- Accepted constraint: `NOTE: <limit or trade-off>. Action: <when it matters>.` Deferred work: `TODO: <shortcut>. Upgrade when <trigger>.` No TODO without a trigger.
