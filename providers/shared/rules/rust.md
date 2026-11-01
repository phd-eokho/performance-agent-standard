# Rust

## Ownership and memory
- Borrow by default (`&T`, `&[T]`, `&str`); `&mut` only for in-place mutation; no `.clone()`, `.to_owned()`, or `.to_string()` on hot paths without a multi-owner reason.
- `Box` for exclusive heap values and recursive types; `Rc`/`Arc` only for genuinely shared lifetimes; `Arc<[T]>`/`Arc<str>` over `Arc<Vec<T>>`/`Arc<String>`; `Weak` to break cycles.
- `Cow<'a, B>` when data is modified only on some paths.
- Self-referential, intrusive, or async-generator types: `Pin<P>` with `PhantomPinned` or explicit `Unpin` bounds.
- Raw-pointer wrappers and FFI: `NonNull<T>` (so `Option<NonNull<T>>` stays pointer-sized), not `*mut T`.
- Deferred initialization: `MaybeUninit<T>` with `write`/`assume_init`; never `mem::uninitialized`.
- Cleanup and state restoration live in `Drop` guards (`ManuallyDrop` for explicit order); no manual cleanup on error paths.
- Zero-sized types (`PhantomData`) for capability tokens, allocator tags, and compile-time states.

## Layout and collections
- `#[repr(C)]` for FFI, hardware, and SIMD structures; `#[repr(transparent)]` for single-field wrappers; `#[repr(packed)]` only when an external format requires it.
- Hot-path sequences bounded at N <= 64: `[T; N]`, or `ArrayVec`/`SmallVec` when already a dependency.
- Lookups with N < 5000: slices or `Vec` with binary search, or `HashMap` (`FxHashMap`/`AHashMap` for integer keys when available); `BTreeMap` only for ordered traversal or range queries.
- Transform and reduce collections with iterator chains (`iter().map().sum()`, `fold(f32::MAX, f32::min)`) instead of index loops.

## Arithmetic and bits
- Arithmetic on untrusted or computed values states its semantics: `checked_*`, `saturating_*`, or `wrapping_*`.
- Identifiers and handles where zero means empty: `NonZeroU32`/`NonZeroU64`/`NonZeroUsize`.
- Bit operations: `count_ones`, `leading_zeros`, `trailing_zeros`, `reverse_bits`.
- Byte reinterpretation: `bytemuck` or `zerocopy` (`Pod`/`Zeroable`) when already a dependency, else `from_ne_bytes`/`to_ne_bytes` or `align_to`; `transmute` only with a size and alignment proof.
- SIMD loops: contiguous slices, loop-invariant bounds, no divergent branches; or `core::arch` intrinsics on aligned slices.

## Concurrency
- Atomics use the weakest correct `Ordering`; `SeqCst` only when a total order across several atomics is required.
- Spin-wait loops call `std::hint::spin_loop()`.
- When a lock is required, use `parking_lot` locks (no poisoning) when already a dependency, else `std::sync::Mutex`; `RwLock` for read-heavy workloads.
- Channels are bounded (`std::sync::mpsc::sync_channel`, or `crossbeam_channel::bounded`/`tokio::sync::mpsc::channel` when already a dependency); never unbounded in production.
- CPU-bound collection transforms: `rayon` (`par_iter`, `par_bridge`) when already a dependency, else `std::thread::scope` over chunks; no detached manual threads.

## Traits and dispatch
- Static dispatch (`impl Trait`, generics) by default; `dyn` only for heterogeneous collections or code-size limits.
- `#[inline]` on small leaf functions called across crates; never blanket `#[inline(always)]` on large functions.
- Statically provable state machines and builders use the type-state pattern, not runtime boolean checks.
- Helpers on foreign types are extension traits, not allocating wrapper types.

## Errors and builds
- Propagate with `?` and combinators (`map`, `and_then`, `ok_or`); no `unwrap`/`expect` in library code.
- `#[must_use]` on values representing ownership, status, or builder state.
- Cold paths go in `#[cold] #[inline(never)]` functions; `unreachable_unchecked` only with a proof.
- Release profile: `lto = "thin"` or `"fat"`, `codegen-units = 1`; `panic = "abort"` only for binaries that never rely on unwinding.
- FFI exports: `#[no_mangle] pub extern "C" fn` with C-compatible types or opaque pointers, body wrapped in `catch_unwind`.
