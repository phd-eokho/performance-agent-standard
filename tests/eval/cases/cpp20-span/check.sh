#!/usr/bin/env bash
# Checks rules/cpp.md C++20 row and rules/native.md: span by value, false-sharing alignment, member naming, final.
set -euo pipefail
f="$1/include/dsp.hpp"
fail=0
grep -Eq 'std::span<const float>[[:space:]]+[a-z_]+' "$f" || {
  printf "no std::span<const float> by value\n"
  fail=1
}
grep -Eq 'const float ?\* ?[a-z_]*, *(std::)?size_t' "$f" && {
  printf "pointer + length parameters\n"
  fail=1
}
grep -Eq 'alignas\(64\)|hardware_destructive_interference_size' "$f" || {
  printf "no 64-byte alignment on cursors\n"
  fail=1
}
grep -Eq '[a-z]+_ *(\{|=|;)' "$f" || {
  printf "members lack trailing underscore\n"
  fail=1
}
grep -Eq 'class RingCursor final' "$f" || {
  printf "RingCursor not final\n"
  fail=1
}
exit "$fail"
