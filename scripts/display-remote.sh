#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_LAYOUT="$ROOT_DIR/layouts/remote.displayplacer"
LOCAL_LAYOUT="$ROOT_DIR/layouts/local.displayplacer"

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
  display-remote.sh [layout-file]

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

current_command="$(displayplacer list | awk '/^displayplacer / { command = $0 } END { print command }')"
if [[ -n "$current_command" && "$command_line" == "$current_command" ]]; then
  cat <<EOF
Already at requested remote display layout.

Layout: $layout_path
EOF
  exit 0
fi

if [[ "$layout_path" == "$DEFAULT_LAYOUT" && -f "$LOCAL_LAYOUT" ]]; then
  local_command="$(read_layout_command "$LOCAL_LAYOUT" || true)"
  if [[ -n "$local_command" && "$command_line" == "$local_command" ]]; then
    cat >&2 <<EOF
Error: remote and local layouts are identical.

Remote: $DEFAULT_LAYOUT
Local:  $LOCAL_LAYOUT

Running this would not change the display. Capture a distinct remote layout:
  $SCRIPT_DIR/capture-layout.sh remote
EOF
    exit 1
  fi
fi

printf 'Applying remote display layout from %s\n' "$layout_path"
if ! output="$(bash -c "$command_line" 2>&1)"; then
  printf '%s\n' "$output" >&2

  if [[ "$output" == *"could not find res:"* ]]; then
    cat >&2 <<'EOF'

The requested display mode is not currently available to displayplacer.

If you are already connected through Screens/VNC, macOS may be exposing a
virtual display with a reduced mode list. Run the remote layout before
connecting, or recapture this layout from the same display context.
EOF
  fi

  exit 1
fi

printf '%s\n' "$output"
