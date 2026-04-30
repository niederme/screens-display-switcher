#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_LAYOUT="$ROOT_DIR/layouts/remote.displayplacer"

usage() {
  cat <<'EOF'
Usage:
  go-remote.sh [layout-file]

Applies the remote display layout. Defaults to:
  layouts/remote.displayplacer
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

layout_path="${1:-$DEFAULT_LAYOUT}"

if ! command -v displayplacer >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Error: displayplacer is not installed.

Install it with:
  brew install displayplacer
EOF
  exit 127
fi

if [[ ! -f "$layout_path" ]]; then
  cat >&2 <<EOF
Error: layout file not found: $layout_path

Capture it first:
  $SCRIPT_DIR/capture-layout.sh remote
EOF
  exit 1
fi

if [[ "$layout_path" == *.example ]]; then
  cat >&2 <<EOF
Error: refusing to run example layout: $layout_path

Capture a real remote layout first:
  $SCRIPT_DIR/capture-layout.sh remote
EOF
  exit 1
fi

command_line="$(
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^displayplacer / { print; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$layout_path"
)" || {
  cat >&2 <<EOF
Error: no displayplacer command found in $layout_path
EOF
  exit 1
}

case "$command_line" in
  *PLACEHOLDER*|*"your-display-id"*|*"your-mode"*)
    cat >&2 <<EOF
Error: refusing to run placeholder layout: $layout_path
EOF
    exit 1
    ;;
esac

printf 'Applying remote display layout from %s\n' "$layout_path"
bash -c "$command_line"
