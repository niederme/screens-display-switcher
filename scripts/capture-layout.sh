#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAYOUTS_DIR="$ROOT_DIR/layouts"

usage() {
  cat <<'EOF'
Usage:
  capture-layout.sh local
  capture-layout.sh remote
  capture-layout.sh path/to/layout.displayplacer

Captures the current display arrangement using `displayplacer list` and writes
the restorable displayplacer command to a layout file.
EOF
}

require_displayplacer() {
  if ! command -v displayplacer >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Error: displayplacer is not installed.

Install it with:
  brew install displayplacer
EOF
    exit 127
  fi
}

resolve_output_path() {
  local target="$1"

  case "$target" in
    local|remote)
      printf '%s/%s.displayplacer\n' "$LAYOUTS_DIR" "$target"
      ;;
    *)
      printf '%s\n' "$target"
      ;;
  esac
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

require_displayplacer

output_path="$(resolve_output_path "$1")"
mkdir -p "$(dirname "$output_path")"

apply_script="display-remote.sh"
if [[ "$1" == "local" ]]; then
  apply_script="display-restore.sh"
fi

command_line="$(
  displayplacer list | awk '
    /^displayplacer / { command = $0 }
    END {
      if (command != "") {
        print command
      } else {
        exit 1
      }
    }
  '
)" || {
  cat >&2 <<'EOF'
Error: could not find a restorable `displayplacer ...` command in
`displayplacer list` output.
EOF
  exit 1
}

{
  printf '# Captured by screens-display-switcher on %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf '# Apply with: ../scripts/%s %s\n' "$apply_script" "$output_path"
  printf '%s\n' "$command_line"
} >"$output_path"

printf 'Captured current layout to %s\n' "$output_path"
