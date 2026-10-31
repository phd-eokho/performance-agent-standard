# Bash

- Start every script with `set -euo pipefail`.
- Configurable values: `NAME=${NAME:-default}`; invariant constants are assigned directly (`NC='\033[0m'`).
- Check failures inline: `cmd || { log_error "msg"; exit 1; }`.
- Print with `printf`, never `echo`.
- Register `trap 'cleanup' EXIT` immediately after creating temp files, taking locks, or changing directories.
- Stream between processes with pipelines or `mkfifo`, not temp files.
- Scripts verify directory changes, inputs, and required commands; skip checks for improbable environments.
- README and doc examples assume the happy path and change directories in a subshell: `(cd dir && cmd)`.
- Log only through these level functions, defining just the levels the script uses (global `NC`, color local to each function, warnings and errors to stderr):

```bash
NC='\033[0m'
log_debug() {
  local cyan='\033[0;36m'
  printf "%b[DEBUG]%b %s\n" "$cyan" "$NC" "$1"
}
log_info() {
  local green='\033[0;32m'
  printf "%b[INFO]%b %s\n" "$green" "$NC" "$1"
}
log_warn() {
  local yellow='\033[1;33m'
  printf "%b[WARN]%b %s\n" "$yellow" "$NC" "$1" >&2
}
log_error() {
  local red='\033[0;31m'
  printf "%b[ERROR]%b %s\n" "$red" "$NC" "$1" >&2
}
```
