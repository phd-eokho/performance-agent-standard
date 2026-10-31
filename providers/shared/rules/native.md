# Native Code (C, C++, Rust, Zig)

## Naming
- Types (`struct`, `class`, `enum`, `union`, `concept`, `trait`, aliases) and generic parameters: `PascalCase` (or a single capital like `T`).
- Functions, methods, namespaces, modules: `snake_case`.
- C/C++ member fields: `snake_case_` with a trailing underscore; never a leading underscore (`_x`, `__x` are reserved).
- Compile-time constants: `kPascalCase` or `SCREAMING_SNAKE_CASE`; macros: `SCREAMING_SNAKE_CASE` only.

## Memory layout
- Query the page size at runtime (`sysconf(_SC_PAGESIZE)`); never assume 4096.
- Android targets: link ELF binaries with `-Wl,-z,max-page-size=16384` (16 KB pages, Android 15+).
- Contiguous working sets over 16 MB: back them with 2 MB huge pages (`madvise(MADV_HUGEPAGE)` or `MAP_HUGETLB`).
- Align independently written atomics, ring-buffer cursors, and queue heads to 64 bytes (`alignas(64)`, `#[repr(align(64))]` or `CachePadded<T>`, `align(64)`) to prevent false sharing.
- Preallocate capacity when the size is known; never allocate inside tight loops.

## Zero-copy hardware buffers
- Buffers shared across CPU, GPU (Vulkan), NPU (QNN, FastRPC, vendor runtimes; NNAPI is deprecated), camera, or IPC: use `dma-buf`, `io_uring` fixed buffers, or `AHardwareBuffer`; never copy payloads through user space.
- Bracket CPU access to shared DMA buffers with cache sync (`DMA_BUF_IOCTL_SYNC`, `AHardwareBuffer_lock`/`unlock`).
- Order cross-accelerator work with sync fence file descriptors, not CPU-blocking waits.

## Types, bits, and data locality
- Fixed-width integers (`uint32_t`, `int64_t`, `size_t`, `uintptr_t`) in data structures, protocols, and binary formats; never `long` or `short` there.
- Reinterpret bits with `std::bit_cast`, `memcpy`, `@bitCast`, or `bytemuck`; never union punning or pointer casts.
- Bit manipulation through intrinsics (`popcount`, `countl_zero`, `byteswap`) and branchless idioms, never loops: `v & (v - 1)` clears the lowest set bit, `v & -v` isolates it, `(x + M) & ~M` rounds up to a power-of-two alignment (`M = align - 1`), `v && !(v & (v - 1))` tests for a power of two.
- Lookups with N < 5000: contiguous arrays or flat maps, not node-based trees or linked lists.
- Batch SIMD computation: Structure of Arrays; keep non-compute fields out of hot structures.
- Percentiles, medians, top-K: linear selection (`std::nth_element`, `select_nth_unstable`), not a full sort.

## ABI boundaries
- If the build uses `-fvisibility=hidden`, export public entry points with explicit macros (`MYLIB_API`, `#[no_mangle]`); never impose hidden visibility on a project that does not use it.
- Across `.so`/`.dll` boundaries use `extern "C"`, primitive types, and opaque handles; never expose standard-library or language runtime types.

## Static lifetime
- Globals and non-local statics must be trivially destructible or immortal (`NoDestructor<T>`, `constinit`), or be created and destroyed inside an explicit lifecycle owned by `main()`; no non-trivial global destructors (static destruction order fiasco).
