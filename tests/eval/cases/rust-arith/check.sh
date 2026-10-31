#!/usr/bin/env bash
# Checks rules/rust.md: explicit arithmetic semantics, borrowed parameters, iterator reductions.
set -euo pipefail
f="$1/src/lib.rs"
fail=0
grep -Eq 'saturating_sub|checked_sub' "$f" || {
  printf "no saturating_sub/checked_sub\n"
  fail=1
}
grep -Eq 'fn count_words\([a-z_]+: *&str' "$f" || {
  printf "count_words does not borrow &str\n"
  fail=1
}
grep -Eq '\.iter\(\)|\.copied\(\)|\.fold\(|\.reduce\(' "$f" || {
  printf "min_sample not an iterator reduction\n"
  fail=1
}
grep -Eq 'for +[a-z_]+ +in +0\.\.' "$f" && {
  printf "index loop used\n"
  fail=1
}
exit "$fail"
