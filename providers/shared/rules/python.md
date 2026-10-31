# Python

Use the newest syntax the project's `requires-python` allows.

- Type hints use builtins and `|` (`list[int]`, `int | None`), not `typing.List` or `Optional`.
- Model data as `@dataclass(frozen=True, slots=True, kw_only=True)`; update with `dataclasses.replace()`.
- `match`/`case` for discrete routing and for destructuring dicts, API responses, and JSON.
- Move condition-heavy branching into helpers; inner functions or lambdas for local cases.
- EAFP: a narrow `try`/`except` instead of pre-checks.
- Comprehensions or `map`/`filter` instead of loops that append; never mutate a collection while iterating it.
- Pipelines use generators and `itertools`; stream instead of building large lists.
- Scope resources with `with`; write context managers with `@contextlib.contextmanager` and `try`/`finally` around `yield`.
- Compose pure functions with `functools`: `partial` to bind dependencies, `reduce`, `singledispatch`.
- `@override` on overriding methods; `@deprecated` with a migration path on obsolete public APIs.
- Concurrency: `asyncio` tasks with `asyncio.Queue` for I/O; `ProcessPoolExecutor` for CPU work; no threads sharing locks.
- Slice binary buffers through `memoryview`.
- With NumPy: preallocate (`np.empty`), operate in place (`+=`, `out=`), never grow arrays (`np.append`); broadcasting, ufuncs, and masks instead of Python loops.
- With Numba: `@njit` (never object mode); fused explicit loops inside; preallocate outputs and pass them in.
