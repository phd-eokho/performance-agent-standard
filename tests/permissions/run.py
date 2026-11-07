#!/usr/bin/env python3
"""Checks compiled permission rules against tests/permissions/cases.tsv.

Matching reproduces each agent's verified semantics (scripts/permissions/compile.sh header):
- Both: a command splits into segments at &&, ||, ;, |, &; deny beats ask beats allow; a segment no rule
  allows asks; the command takes the strictest segment verdict.
- agy: command(<words>) matches a word prefix; command(regex:<tokens>) fully matches one word per token,
  from the first word on, and is ignored in deny. A file redirection or a command substitution asks.
- Claude: Bash(<glob>) matches the segment text, * spanning words; a trailing " *" as the only wildcard also
  matches the bare command. Commands Claude classifies itself (policy claude_builtin) are not simulated.
"""

from __future__ import annotations

import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = ROOT / "tests" / "permissions" / "cases.tsv"
COMPILER = ROOT / "scripts" / "permissions" / "compile.sh"
OPERATORS = {"&&", "||", ";", "|", "&", "|&"}
VERDICT_ORDER = {"allow": 0, "ask": 1, "deny": 2}


def compile_rules(provider: str) -> dict[str, list[str]]:
    out = subprocess.run(["bash", str(COMPILER), provider], check=True, capture_output=True, text=True)
    return json.loads(out.stdout)


def segments(command: str) -> list[list[str]]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    parts: list[list[str]] = [[]]
    for token in lexer:
        if token in OPERATORS:
            parts.append([])
        else:
            parts[-1].append(token)
    return [p for p in parts if p]


def agy_matches(rule: str, words: list[str]) -> bool:
    body = rule[len("command(") : -1]
    if body.startswith("regex:"):
        tokens = body[len("regex:") :].split(" ")
        return (
            len(words) >= len(tokens)
            and words[0] == tokens[0]
            and all(re.fullmatch(t, w) for t, w in zip(tokens[1:], words[1:]))
        )
    tokens = body.split(" ")
    return words[: len(tokens)] == tokens


def claude_matches(rule: str, words: list[str]) -> bool:
    glob = rule[len("Bash(") : -1]
    bare_ok = glob.endswith(" *") and glob.count("*") == 1
    base = glob[:-2] if bare_ok else glob
    pattern = ".*".join(re.escape(p) for p in base.split("*")) + ("(?: .*)?" if bare_ok else "")
    return re.fullmatch(pattern, " ".join(words), re.DOTALL) is not None


def segment_verdict(rules: dict[str, list[str]], words: list[str], matches) -> str:
    for layer in ("deny", "ask", "allow"):
        if any(matches(r, words) for r in rules[layer]):
            return layer
    return "ask"


def split_redirects(words: list[str]) -> tuple[list[str], list[str]]:
    """Returns the words without redirections, and the redirection targets."""
    targets = [words[i + 1] for i, w in enumerate(words[:-1]) if w in {">", ">>"}]
    kept = [w for i, w in enumerate(words) if w not in {">", ">>"} and (i == 0 or words[i - 1] not in {">", ">>"})]
    return kept, targets


def verdict(provider: str, rules: dict[str, list[str]], command: str) -> str:
    if provider == "claude":
        return max((segment_verdict(rules, w, claude_matches) for w in segments(command)), key=VERDICT_ORDER.get)
    if "$(" in command or "`" in command:
        return "ask"
    rules = {**rules, "deny": [r for r in rules["deny"] if not r.startswith("command(regex:")]}
    verdicts = []
    for words in segments(command):
        kept, targets = split_redirects(words)
        verdicts.append("ask" if any(t != "/dev/null" for t in targets) else "allow")
        verdicts.append(segment_verdict(rules, kept, agy_matches))
    return max(verdicts, key=VERDICT_ORDER.get)


def main() -> int:
    rules = {p: compile_rules(p) for p in ("antigravity", "claude")}
    passed = failed = 0
    for line in CASES.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        provider, expect, command = line.split("\t", 2)
        got = verdict(provider, rules[provider], command)
        if got == expect:
            passed += 1
        else:
            failed += 1
            print(f"[ERROR] {provider}: expected {expect}, got {got}: {command}", file=sys.stderr)
    print(f"[INFO] permission cases: {passed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
