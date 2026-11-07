#!/usr/bin/env bash
# ---
# purpose: Compiles policy.json into one agent's permission rules, printed as {"allow": [...], "ask": [...], "deny": [...]}.
# ---
# policy.json is the read-only boundary: an allowed command never changes the remote and makes no local change that
# could later reach it; downloads (fetch, clone, release or artifact download) count as reads. A command no rule
# allows asks. Group fields:
#   prefixes        commands to allow, as literal word prefixes (patterns: agy regex prefixes instead, agy only)
#   ask             options or subcommands that cross the boundary, by the command's own --help: they write a file,
#                   ref, object, or configuration, move a local branch, or run a program
#   ask_agy         agy word regexes for crossings no glob can express (bundled short flags, any operand)
#   deny            options that only name a program to run in place of the remote's (--upload-pack)
#   forwards        the group whose ask, ask_agy, and deny apply to the words after a -- word (gh clone commands
#                   pass git clone flags there)
#   literal_dollar  $ is program text (awk, sed), not an expansion that could hide an option, so it does not ask
#   claude: false   no Claude rule, so Claude Code asks for every use
#   why             the --help evidence, including each crossing option the owner chose to allow
# claude_builtin lists the prefixes Claude Code classifies itself; the top-level deny lists whole commands.
#
#   antigravity: allows are literal word prefixes, command(<prefix>). agy matches a regex rule word by word: each
#                whitespace-separated token must fully match one command word, from the first word on, and `.*`
#                spans one word only. A crossing option is therefore asked at every argument position below
#                max_args (a forwarded one at every position pair of -- and option), and a length cap asks for any
#                longer command, so no position escapes. agy ignores regex rules in deny, so a denied option asks the
#                same way; only whole-command denies are literal deny rules.
#                Every regex token is parenthesized: agy shell-unescapes rule text outside parentheses (\x7c becomes
#                x7c, \$ becomes $).
#   claude:      Claude Code classifies its built-in read-only commands itself, flag by flag; a Bash allow rule
#                would only widen that, so commands in claude_builtin get no rule. Other commands get
#                Bash(<prefix>) and Bash(<prefix> *); a * glob spans words, so one ask or deny rule covers every
#                position.
# Usage: compile.sh antigravity|claude

set -euo pipefail

POLICY=${POLICY:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/policy.json"}
provider="${1:-}"

case "$provider" in
  antigravity | claude) ;;
  *)
    printf "Usage: compile.sh antigravity|claude\n" >&2
    exit 1
    ;;
esac

jq --arg provider "$provider" '
  # Literal words never carry shell or regex metacharacters, so both agents read them verbatim.
  def check_word: if test("^-{0,2}[A-Za-z0-9][A-Za-z0-9._-]*$") then . else error("not a plain word: \(.)") end;
  def names($list): [($list // [])[] | check_word];
  def range_join($n; $s): [range($n)] | map($s) | join("");

  # agy word regex for an option name: --long[=value], -s[value or bundle tail], or an exact word.
  def agy_word_re:
    if startswith("--") then "\(.)(=.*)?" elif test("^-.$") then "\(.).*" else . end;
  def agy_crossing($g): [names(($g.ask // []) + ($g.deny // []))[] | agy_word_re] + ($g.ask_agy // []);
  def alternation: "(" + join("|") + ")";
  # One rule per argument position below $max: "<prefix> (.*) ... (<alternation>)".
  def agy_positions($p; $alt; $max): range($max) | "command(regex:\($p)\(range_join(.; " (.*)")) \($alt))";
  # One rule per pair of a -- position and a later option position, both below $max.
  def agy_positions_after_dashdash($p; $alt; $max):
    range($max - 1) as $i | range($max - 1 - $i)
    | "command(regex:\($p)\(range_join($i; " (.*)")) (--)\(range_join(.; " (.*)")) \($alt))";
  def forwarded($groups; $prefix):
    first($groups[] | select(any(.prefixes[]?; . == $prefix))) // error("forwards to an unknown prefix: \($prefix)");
  # Prefixes that share a first word and a length merge into one rule prefix: "git (log|show)".
  def agy_prefixes($g):
    if $g.patterns then $g.patterns[]
    else
      $g.prefixes | map(split(" ") | map(check_word)) | group_by([.[0], length])[]
      | . as $ws | [range($ws[0] | length) | . as $i | $ws | map(.[$i]) | unique
        | if length == 1 then .[0] else "(" + join("|") + ")" end] | join(" ")
    end;
  def agy($max):
    {
      allow: [(.groups[] | (.prefixes // [])[] | "command(\(.))"), (.groups[] | (.patterns // [])[] | "command(regex:\(.))")],
      # The length cap asks for any command longer than the enumerated positions.
      ask: [.groups as $groups | $groups[] | select((agy_crossing(.) | length) > 0 or .forwards) | . as $g
        | agy_prefixes($g) as $p
        | (agy_crossing($g) + (if $g.literal_dollar then [] else [".*\\$.*"] end)) as $own
        | (if ($own | length) > 0 then agy_positions($p; $own | alternation; $max) else empty end),
          (if $g.forwards then agy_positions_after_dashdash($p; agy_crossing(forwarded($groups; $g.forwards)) | alternation; $max)
            else empty end),
          "command(regex:\($p)\(range_join($max; " (.*)")))"],
      deny: [.deny[] | "command(\(.))"]
    };

  # Claude globs: options match as a word prefix (--output=x), subcommand words as whole words.
  def claude_globs($p):
    if startswith("-") and (startswith("--") or test("^-.$")) then "Bash(\($p) \(.)*)", "Bash(\($p) * \(.)*)"
    else "Bash(\($p) \(.))", "Bash(\($p) \(.) *)", "Bash(\($p) * \(.))", "Bash(\($p) * \(.) *)" end;
  def claude:
    .claude_builtin as $builtin | .groups as $all
    | [.groups[] | select(.claude != false) | . as $g
      | if $g.forwards then error("forwards need \"claude\": false") else . end
      | {g: $g, own: [($g.prefixes // error("patterns need \"claude\": false"))[] | select(IN($builtin[]) | not)]}
      | select(.own | length > 0)
      | if .g.ask_agy then error("agy-only asks cannot be expressed for Claude: \(.own)") else . end] as $groups
    | {
        allow: [$groups[] | .own[] | "Bash(\(.))", "Bash(\(.) *)"],
        ask: [$groups[] | .g as $g | .own[] as $p | names($g.ask)[] | claude_globs($p)],
        # A Claude glob cannot hold a literal *; bash-guard blocks wildcard removals instead. Option denies only
        # narrow, so they apply to every group, built-in or not.
        deny: [(.deny[] | select(contains("*") | not) | "Bash(\(.))", "Bash(\(.) *)"),
          (.groups[] | select(.deny) | . as $g | ($g.prefixes // [])[] as $p | names($g.deny)[] | claude_globs($p)),
          (.groups[] | select(.forwards) | . as $g | ($g.prefixes // [])[] as $p
            | names(forwarded($all; $g.forwards).deny)[] | claude_globs("\($p) * --"))]
      };

  (if $provider == "antigravity" then agy(.max_args) else claude end) | map_values(unique)
' "$POLICY"
