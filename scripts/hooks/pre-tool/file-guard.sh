#!/usr/bin/env bash
# ---
# purpose: PreToolUse hook blocking direct edits to secrets, environment/state files, lockfiles, and Git metadata.
# ---

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Basename rules ("<regex>:::<reason>").
NAME_RULES=(
  "(\.(pem|key|p12|pfx|pkcs12|kdbx|keystore)|^id_(rsa|ed25519|ecdsa|dsa)(\.pub)?)$:::[file-guard] Secret/key mutation blocked. Isolate credentials."
  "^(\.env(\..+)?|.+\.tfstate(\..+)?)$:::[file-guard] Env/state mutation blocked. Protect secrets."
  "^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|poetry\.lock|uv\.lock|composer\.lock|Gemfile\.lock)$:::[file-guard] Lockfile mutation blocked. Use the package manager CLI."
)
# Canonical path rules.
PATH_RULES=(
  "(^|/)\.git(/|$):::[file-guard] Git metadata mutation blocked. Use the git CLI."
)
# Committed templates are safe to edit.
TEMPLATE_SUFFIX='\.(example|sample|template|dist)$'

target=$(pas_file)
[[ -n "$target" ]] || exit 0

canonical=$(realpath -m -- "$target" 2> /dev/null || printf "%s" "$target")
name=${canonical##*/}

printf "%s\n" "$name" | grep -Eq "$TEMPLATE_SUFFIX" && exit 0
pas_guard "$name" "${NAME_RULES[@]}"
pas_guard "$canonical" "${PATH_RULES[@]}"
