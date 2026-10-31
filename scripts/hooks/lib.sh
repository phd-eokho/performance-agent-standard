#!/usr/bin/env bash
# ---
# purpose: Shared hook helpers sourced by every hook: reads the payload once, extracts fields, emits responses.
# ---
# Response schema: Claude Code hook JSON (agy imports Claude plugins and reads the same keys).
# Allow = print nothing and exit 0. Fail open (allow) when jq or the payload is missing.
# shellcheck disable=SC2016  # jq programs are single-quoted on purpose ($a is a jq variable)

PAS_PAYLOAD=""
[[ -t 0 ]] || PAS_PAYLOAD=$(cat)

# Normalizes tool arguments across Claude (`tool_input`) and agy (`toolCall.arguments` / `arguments`) envelopes.
PAS_ARGS_FILTER='(if .tool_input != null then .tool_input
  else ((.toolCall.arguments // .arguments // {}) | if type == "string" then (fromjson? // {}) else . end) end)'

# Evaluates a jq expression with `$a` bound to the normalized tool arguments; prints nothing on miss.
pas_field() {
  [[ -n "$PAS_PAYLOAD" ]] && command -v jq &> /dev/null || return 0
  jq -r "${PAS_ARGS_FILTER} as \$a | (${1}) // empty" <<< "$PAS_PAYLOAD" 2> /dev/null || true
}

pas_command() { pas_field '$a.command // $a.CommandLine // $a.cmd'; }
pas_file() { pas_field '$a.file_path // $a.TargetFile // $a.AbsolutePath // $a.filePath // $a.path'; }
pas_workspace() { pas_field '.cwd // .workspacePaths[0] // .workspacePath'; }
pas_session() { pas_field '.session_id // .sessionId // .conversationId // .conversation_id'; }
pas_source() { pas_field '.source'; }

# Blocks the pending tool call; the reason is shown to the agent.
pas_deny() {
  jq -cn --arg r "$1" \
    '{decision: "block", reason: $r,
      hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# Feeds a post-tool problem (e.g. failed format check) back to the agent.
pas_feedback() {
  jq -cn --arg r "$1" '{decision: "block", reason: $r}'
  exit 0
}

# Adds text to the agent context. Arguments: event name, text.
pas_context() {
  jq -cn --arg e "$1" --arg t "$2" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $t}}'
  exit 0
}

# Matches a command line against a "<regex>:::<reason>" rule table; denies on the first hit.
pas_guard() {
  local subject="$1" rule
  shift
  [[ -n "$subject" ]] || return 0
  for rule in "$@"; do
    printf "%s\n" "$subject" | grep -Eq -- "${rule%%:::*}" && pas_deny "${rule##*:::}"
  done
  return 0
}
