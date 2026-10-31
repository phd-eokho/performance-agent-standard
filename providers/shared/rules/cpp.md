# C++

## Lifetime and ownership
- Unique resource handles declare `NON_COPYABLE(T)` / `NON_MOVEABLE(T)` (explicit `= delete` in `public:`), not implicit deletion or private declarations.
- Composite types follow the Rule of Zero; raw handle wrappers follow the Rule of Five with `noexcept` moves; never a partial set.
- Own heap objects with `std::make_unique`; `std::shared_ptr` only for multiple owners; `std::weak_ptr` for back-references; no owning raw `new`.
- Custom deleters are stateless functors (`operator() const noexcept`) so `sizeof(unique_ptr<T, D>) == sizeof(void*)`; no stateful lambdas or function pointers.
- Placement `new` only through `InPlaceUniquePtr` over `alignas(T)` storage; `std::launder` when storage is reused.
- Non-local statics with non-trivial destructors are wrapped in `NoDestructor<T>`.

```cpp
#define NON_COPYABLE(T) T(const T&) = delete; T& operator=(const T&) = delete
#define NON_MOVEABLE(T) T(T&&) = delete; T& operator=(T&&) = delete

struct InPlaceDeleter final {
    template <typename T> void operator()(T* p) const noexcept { if (p) p->~T(); }
};
template <typename T> using InPlaceUniquePtr = std::unique_ptr<T, InPlaceDeleter>;

template <typename T>
class NoDestructor final {
public:
    template <typename... Args>
    explicit constexpr NoDestructor(Args&&... args) noexcept { ::new (static_cast<void*>(storage_)) T(std::forward<Args>(args)...); }
    NON_COPYABLE(NoDestructor);
    NON_MOVEABLE(NoDestructor);
    [[nodiscard]] T* get() noexcept { return std::launder(reinterpret_cast<T*>(storage_)); }
    [[nodiscard]] const T* get() const noexcept { return std::launder(reinterpret_cast<const T*>(storage_)); }
    [[nodiscard]] T* operator->() noexcept { return get(); }
    [[nodiscard]] const T* operator->() const noexcept { return get(); }
    [[nodiscard]] T& operator*() noexcept { return *get(); }
    [[nodiscard]] const T& operator*() const noexcept { return *get(); }
private:
    alignas(T) std::uint8_t storage_[sizeof(T)];
};
```

## Types and dispatch
- `struct` is a passive aggregate: public fields, trivial copy, no business methods. `class` is a processor: private `name_` state, `const` queries.
- Mark concrete classes and virtual overrides `final`.
- Callable parameters are templates or invocables dispatched with `std::invoke`.

## Expressions and parameters
- Locals use `auto` (`const auto`, `const auto&`, `auto&&`); spell the type only for conversions or literal disambiguation.
- Range-based `for`; index loops only when the index or a custom stride is needed.
- Pass scalars (`int`, `uint32_t`, `double`, enums) by value, never `const T&`; pass non-scalars as `const T&` or views.
- Locals are `const` by default; multi-branch initialization uses an immediately invoked lambda (`const auto x = [&] { ... }();`).
- Pure deterministic functions are `constexpr`.

## Translation units and low level
- Headers never contain `using namespace`; a `.cpp` may add `using namespace std;` after all includes; internal helpers go in an anonymous namespace; aliases use `using`, never `typedef`; template metaprogramming stays at the level of concepts.
- Branch hints (`[[likely]]`, `[[unlikely]]`) only on branches above 99% or below 1%.
- Fixed-size buffers are stack arrays (`T buf[N] = {};`); no VLAs or `alloca`.
- Shared state uses `std::atomic` with `compare_exchange_weak` loops and explicit acquire/release ordering; no default `seq_cst`, no unsynchronized mutation.
- Do not link `std::regex`, `std::locale`, `<codecvt>`, or Boost; parse with `string_view` state machines or C/POSIX functions.

## Language standard
Use the idioms of the project's standard (`CMAKE_CXX_STANDARD`, `-std=`) and never features above it.

| Standard | Use | Instead of a newer feature, use |
|---|---|---|
| C++17 | `std::string_view` by value; structured bindings; `if constexpr`; fold expressions; `std::variant`/`std::optional` instead of out-parameters; `std::pmr::monotonic_buffer_resource` over a stack array for hot-loop containers | concepts → `std::enable_if_t`; `std::span` → pointer + size or `tcb::span`; `<=>` → explicit `==` and `<`; `std::jthread` → RAII-joined `std::thread`; designated initializers → aggregate braces; `std::expected` → `std::variant`/`std::optional` or `tl::expected`; `consteval`/`constinit` → `constexpr` |
| C++20 | concepts/`requires` (no `enable_if`/`void_t`); `std::span<const T>` by value (no pointer + size); `operator<=> = default`; `std::jthread` + `std::stop_token`; designated initializers (no builders); `std::ranges` and `std::views` pipelines; `consteval`/`constinit`; `std::format` (no `stringstream`/`sprintf`); `std::atomic::wait`/`notify_*` instead of busy polling | `std::expected` → `std::variant`/`std::optional` or `tl::expected`; `flat_map` → sorted `std::vector` + `std::lower_bound`; `mdspan` → 1D indexing or Kokkos `mdspan`; deducing `this` → CRTP or `const&`/`&&` overloads; `std::print` → `std::format`; no modules in cross-platform builds (`#pragma once` headers) |
| C++23 | `std::expected` with `and_then`/`transform`/`or_else` (no out-parameters or sentinel codes); `std::flat_map`/`std::flat_set` for N < 10000 (no node-based `map`/`set`); `std::mdspan` (no `ptr[i * cols + j]`, no `T**`); deducing `this` (no CRTP for qualifiers); `std::print`/`std::println` (no `iostream`); `std::unreachable()` in exhaustive switches; `std::generator` (no hand-written iterators); `std::move_only_function` for move-only captures | no C++26 features (contracts, reflection, pack indexing) until shipped in LTS compilers |
