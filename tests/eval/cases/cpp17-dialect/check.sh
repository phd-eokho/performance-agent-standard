#!/usr/bin/env bash
# Checks rules/cpp.md C++17 row: no post-17 features; string_view by value; optional/variant errors.
set -euo pipefail
f="$1/include/net.hpp"
fail=0
grep -Eq 'std::expected|<=>|std::span|concept |requires |consteval|constinit|std::format' "$f" &&
  {
    printf "uses a feature above C++17\n"
    fail=1
  }
grep -Eq 'std::string_view [a-z_]+' "$f" || {
  printf "no string_view by value\n"
  fail=1
}
grep -Eq 'const std::string_view ?&|const std::string ?&' "$f" && {
  printf "view passed by reference\n"
  fail=1
}
grep -Eq 'std::optional|std::variant' "$f" || {
  printf "no optional/variant error channel\n"
  fail=1
}
exit "$fail"
