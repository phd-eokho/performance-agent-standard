#!/usr/bin/env bash
# Checks rules/python.md: frozen slotted kw-only dataclass, replace(), builtin hints, generator, EAFP.
set -euo pipefail
f="$1/geo.py"
[[ -f "$f" ]] || {
  printf "geo.py missing\n"
  exit 1
}
fail=0
grep -Eq '@dataclass\((.*frozen=True.*slots=True.*kw_only=True|.*kw_only=True.*slots=True.*frozen=True|.*frozen=True.*kw_only=True.*slots=True)' "$f" ||
  {
    printf "dataclass not frozen+slots+kw_only\n"
    fail=1
  }
grep -Eq 'replace\(' "$f" || {
  printf "translate does not use dataclasses.replace\n"
  fail=1
}
grep -Eq 'from typing import .*(List|Optional|Dict)' "$f" && {
  printf "legacy typing aliases\n"
  fail=1
}
grep -Eq '\byield\b' "$f" || {
  printf "parse_points is not a generator\n"
  fail=1
}
grep -Eq '\btry:' "$f" || {
  printf "no EAFP try/except\n"
  fail=1
}
exit "$fail"
