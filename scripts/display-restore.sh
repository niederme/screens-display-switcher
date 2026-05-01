#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_LAYOUT="$ROOT_DIR/layouts/local.displayplacer"
REMOTE_LAYOUT="$ROOT_DIR/layouts/remote.displayplacer"

read_layout_command() {
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^displayplacer / { print; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$1"
}

usage() {
  cat <<'EOF'
Usage:
  display-restore.sh [layout-file]

Applies the local display layout. Defaults to:
  layouts/local.displayplacer
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
  $SCRIPT_DIR/capture-layout.sh local
EOF
  exit 1
fi

if [[ "$layout_path" == *.example ]]; then
  cat >&2 <<EOF
Error: refusing to run example layout: $layout_path

Capture a real local layout first:
  $SCRIPT_DIR/capture-layout.sh local
EOF
  exit 1
fi

command_line="$(read_layout_command "$layout_path")" || {
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

if [[ "$layout_path" == "$DEFAULT_LAYOUT" && -f "$REMOTE_LAYOUT" ]]; then
  remote_command="$(read_layout_command "$REMOTE_LAYOUT" || true)"
  if [[ -n "$remote_command" && "$command_line" == "$remote_command" ]]; then
    cat >&2 <<EOF
Error: local and remote layouts are identical.

Local:  $DEFAULT_LAYOUT
Remote: $REMOTE_LAYOUT

Running this would not change the display. Capture a distinct local layout:
  $SCRIPT_DIR/capture-layout.sh local
EOF
    exit 1
  fi
fi

current_command="$(displayplacer list | awk '/^displayplacer / { command = $0 } END { print command }')"
if [[ -n "$current_command" && "$command_line" == "$current_command" ]]; then
  cat <<EOF
Already at requested local display layout.

Layout: $layout_path
EOF
  exit 0
fi

printf 'Applying local display layout from %s\n' "$layout_path"
if ! output="$(bash -c "$command_line" 2>&1)"; then
  printf '%s\n' "$output" >&2

  if [[ "$output" == *"could not find res:"* ]]; then
    cat >&2 <<'EOF'

The requested display mode is not currently available to displayplacer.

If you are already connected through Screens/VNC, macOS may be exposing a
virtual display with a reduced mode list. Disconnect and run the restore layout
locally, or recapture this layout from the same display context.
EOF
  fi

  exit 1
fi

printf '%s\n' "$output"
