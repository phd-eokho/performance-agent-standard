# Rule Coverage: pre-refactor rules → current files

Every rule from the pre-refactor rule set (commit `fc8e073`) and where it now lives. Paths are compiled names under `rules/`.
Status: `kept` (same requirement, reworded) · `conditional` (kept, now gated by when it applies) · `corrected` (kept, factual or contradiction fix) · `moved` (lives elsewhere) · `dropped` (with reason).

## Native (`lang-standard-native` → `native.md`)
| Old rule | Status | Note |
|---|---|---|
| TypeIdentifiersPascalCase, GenericParametersPascalCase, FunctionsAndModulesSnakeCase, MemberVariablesSnakeCase, ConstantsAndMacrosTaxonomy | kept | Naming |
| DynamicPageSizeQuery, CacheLineFalseSharingIsolation | kept | Memory layout |
| AndroidSixteenKbPageAlignment | conditional | Android targets |
| TransparentHugePages | conditional | Working sets over 16 MB |
| HardwareDmaPipelines, ExplicitCacheSynchronization, AsynchronousSyncFences | conditional | Buffers shared across CPU/GPU/NPU/camera/IPC |
| ExactWidthIntegerTypes, SafeBitwiseTypePunning, HardwareBitTwiddlingIntrinsics, ContiguousLookupContainers, StructureOfArraysLayout, LinearTimeSelection | kept | Types, bits, and data locality (all bit idioms retained) |
| ContextualSymbolVisibility, StableCAbiBoundaries | kept | ABI boundaries |
| ProhibitNonTrivialStaticDestructors, DeterministicLifecycleStorage | kept | Static lifetime |
| (pre-2026 native rule) Pre-allocate Collection Capacity | kept | Memory layout |

## Rust (`lang-standard-rust` → `rust.md`)
| Old rule | Status | Note |
|---|---|---|
| OwnershipAndBorrowingHierarchy, SmartPointerDiscipline, ZeroCopyCowBranching, SafePinAndUnpinSemantics, RawPointerSafetyWithNonNull, UninitializedMemorySafety, DeterministicDestructionWithDropGuard, ZeroSizedTypeStateGuards | kept | Ownership and memory |
| ExplicitLayoutRepresentation | kept | Layout |
| CacheLineFalseSharingPadding, StructureOfArraysVectorization | moved | `native.md` (Rust syntax `#[repr(align(64))]`, `CachePadded<T>` included) |
| InlineStackArrayContainers | corrected | `ArrayVec`/`SmallVec` only when already a dependency (dependency policy) |
| ContiguousLookupMapSelection | corrected | std `HashMap` is already hashbrown; Fx/AHash for integer keys when available |
| (pre-2026 rust rule) Zero-Cost Iterator Pipelines | kept | Layout and collections |
| ExplicitArithmeticSemantics, NonZeroValueNpoOptimization, HardwareBitwiseIntrinsics, SafeZeroCopyTransmute, VectorizedSimdPipelines | kept | Arithmetic and bits |
| ExplicitAtomicMemoryOrdering, LockFreeSpinLoops, BoundedChannelBackpressure, ParallelDataPartitioning | kept | Concurrency |
| SynchronizationPrimitiveSelection | corrected | `parking_lot` kept; outdated "40+ bytes" std mutex claim removed (futex-based since Rust 1.62) |
| StaticDispatchOverDynamicTraitObjects, TypeStatePatternEnforcement, ZeroCostExtensionTraits | kept | Traits and dispatch |
| InlineAnnotationDiscipline | corrected | `#[inline]` for small cross-crate leaf functions (in-crate inlining needs no annotation) |
| ResultAndOptionCombinators, MustUseAnnotationHygiene, ColdBranchAndUnlikelyHints, FfiBoundaryCAbiIsolation | kept | Errors and builds |
| ProductionCargoProfileOptimization | corrected | `panic = "abort"` only when nothing relies on unwinding (contradicted `catch_unwind` at FFI) |

## C++ (`lang-standard-cpp`, `-17`, `-20`, `-23` → `cpp.md`)
| Old rule | Status | Note |
|---|---|---|
| NonCopyableMoveableMacros, RuleOfZeroAndFive, SmartPointerSupremacy, StatelessCustomDeleters, InPlacePlacementNewUniquePtr, StaticDestructionSafety | kept | Lifetime and ownership; `NON_COPYABLE`/`NON_MOVEABLE`, `InPlaceUniquePtr`, `NoDestructor` snippet kept as the spec |
| StructuralSeparation, UniversalFinalDevirtualization, ModernDelegationDispatch | kept | Types and dispatch |
| AutoTypeDeduction, RangeBasedForLoops, ParameterPassingConventions, ConstByDefaultIIFE, PureConstexprFunctions | kept | Expressions and parameters |
| TranslationUnitHygiene, BranchPredictionHints, StackCArrayPreallocation, LockFreeAtomicConcurrency, RestrictedStandardLibraries | kept | Translation units and low level |
| All C++17 / C++20 / C++23 "use" and "prohibit/fallback" rules (incl. AtomicNotificationWait, ProhibitModulesInCrossPlatform, ProhibitBleedingEdgeC26Features) | conditional | Language-standard table; only the project's standard row applies (previously all three files loaded for every C++ file) |

## Common, simplicity, and core
| Old rule | Status | Where |
|---|---|---|
| Magic Numbers Avoidance, Parameterized Configs, Usable Defaults | corrected | `code.md`: name all constants; parameterize only what callers vary (contradicted the YAGNI ban on future-proofing parameters) |
| SOLID Design Principles, Pragmatic Application, Readability Priority, Dependency Injection | kept | `code.md` Design; SOLID reached through flat control flow (guard clauses, extracted branches, no flag parameters) |
| Scoped Return Pattern, Native Deterministic Cleanup, Reference Views, Move Semantics, Memory Mapping and OS Splice | kept | `code.md` Resources and data |
| Memory Sharing via Communication, Pipeline Architecture | corrected | `code.md` Concurrency; atomics allowed where shared state is unavoidable (reconciles C++/Rust lock-free rules) |
| Hierarchy Order, Codebase Reuse Priority, Standard Library and Platform Primacy, Speculative Abstraction Ban, Scope Confinement | kept | `AGENTS.md` Approach |
| Colocated Minimal Scaffolding | kept | `code.md` Design |
| Non-Negotiable Boundary Validation, Data-Loss and Security Protection | kept | `code.md` Safety |
| Accessibility and Domain Precision | dropped (accessibility) / kept (precision) | Rule never loaded for frontend files; domain precision in `code.md` |
| Single Runnable Verification Check | corrected | `AGENTS.md`: narrowest existing check (conflicted with "verify test status") |
| Code-First Output Mandate, 3-Line Prose Ceiling | corrected | `AGENTS.md`: result first, no filler (fixed prose ceiling blocked required reporting) |
| Obviousness and Noise Ban, Substantive Concern Requirement, Semantic Tag Selection, Mandatory Actionable Structure, Structured Omission Formula | kept | `code.md` Comments (omission formula merged into the `TODO:` form) |
| 5-Tag Simplicity Taxonomy, Net Reduction Verification, Review Scope Confinement | moved | `review-rust`, `review-cpp`, `review-python` skills |
| Karpathy: Caution Bias, Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution | kept | `AGENTS.md` Approach |
| Development: Precedence Hierarchy, Python/Native/Polyglot Resolution, README Fallback | kept | `AGENTS.md` Execution |
| Development: Zero-Debt Quality Gate | corrected | `AGENTS.md`: smells removed in code you write or modify (conflicted with surgical changes) |
| Development: Deep Module Primacy, Inverse Change Amplification, Deletion Test, Seam Justification | kept | `AGENTS.md` Approach |
| Hygiene: Need-to-Know Reading, Scoped Search and Exclusions, Surgical Line Slicing, Dependency Mapping, Batched Edits, Subagent Isolation | kept | `AGENTS.md` Context |
| Hygiene/Reading: Precedence Hierarchy | kept | `AGENTS.md` first line |
| Inline execution: all rules | kept | `AGENTS.md` Execution |
| agy/Claude `always-read.md`: scoped search, pre-read justification, ask for ambiguous paths, surgical edit tools, no subagent for local edits, test boundaries, plan for open questions, concise replies | kept | `AGENTS.md` (tool-neutral wording) |

## Language and documents
| Old rule | Status | Where |
|---|---|---|
| Python: all 25 rules | kept / conditional | `python.md`; Numba and NumPy rules apply when those libraries are used; syntax follows `requires-python` |
| Bash: all 11 rules | kept | `bash.md`; log template now in shfmt (repo formatter) layout |
| Markdown writing: Nuance Retention, Input Generalization, Padding Elimination, Scope Confirmation, Indentation, Bulleting, Tables, Pseudocode, Block Delimiters, Hierarchical Cohesion | kept | `markdown.md` |
| Markdown writing: Standardized Prefixes, Inline Semantic Indexing, Frontmatter Topic Declaration, Logical Compilation Flow | dropped | HDMD tag machinery; no consumer, costs tokens |
| Markdown reading: Load Order, Non-Redundant Expansion | corrected | Precedence by scope (narrower wins) in `AGENTS.md`; no load order or numbered file names, which made agents search for rule files |
