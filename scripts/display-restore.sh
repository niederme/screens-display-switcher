#!/usr/bin/env bash
set -euo pipefail

# Make sure displayplacer/betterdisplaycli are findable when invoked from a
# minimal-PATH context (Raycast, launchd). Append rather than prepend so a
# caller's PATH still takes precedence (also lets tests substitute stubs).
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

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

layout_has_directive() {
  local layout_file="$1"
  local directive="$2"

  grep -Eiq "^[[:space:]]*#[[:space:]]*$directive([[:space:]]|$)" "$layout_file"
}

layout_directive_value() {
  local layout_file="$1"
  local directive="$2"

  sed -n -E "s/^[[:space:]]*#[[:space:]]*$directive[[:space:]]*//Ip" "$layout_file" | head -n 1
}

# Discard a BetterDisplay virtual screen if the layout file has a
# `# betterdisplay-discard: <args>` directive. Loops until discard reports
# nothing left, so duplicate records are cleaned up in one pass. Quiet on
# success; warns once if betterdisplaycli is missing.
run_layout_discard() {
  local layout_file="$1"
  local discard_args
  discard_args="$(layout_directive_value "$layout_file" "betterdisplay-discard:")"

  [[ -z "$discard_args" ]] && return 0

  if ! command -v betterdisplaycli >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Warning: layout requests a BetterDisplay discard, but betterdisplaycli was not found.
Skipping discard step. Install it with:
  brew install waydabber/betterdisplay/betterdisplaycli
EOF
    return 0
  fi

  # shellcheck disable=SC2086
  while betterdisplaycli discard $discard_args >/dev/null 2>&1; do
    sleep 0.5
  done
}

# Extract the first display id token from a displayplacer command, e.g.
#   displayplacer "id:s1879776955 res:..."  ->  s1879776955
# For a mirror set (id:sA+sB) returns the first segment.
layout_target_id() {
  printf '%s\n' "$1" | sed -n -E 's/.*id:([^ "+]+).*/\1/p' | head -n 1
}

# True if displayplacer currently enumerates a display matching the id token.
displayplacer_has_id() {
  displayplacer list 2>/dev/null | grep -q "$1"
}

# Ask BetterDisplay to reconnect all displays, then poll for the target id to
# reappear. No-op if betterdisplaycli is unavailable. Retry/wait are tunable
# via env vars so tests don't sleep for real.
reconnect_displays() {
  local target_id="$1"
  command -v betterdisplaycli >/dev/null 2>&1 || return 0
  betterdisplaycli perform --connectAllDisplays >/dev/null 2>&1 || true
  local retries="${RESTORE_RECONNECT_RETRIES:-5}"
  local wait_s="${RESTORE_RECONNECT_WAIT:-1}"
  local i
  for ((i = 0; i < retries; i++)); do
    displayplacer_has_id "$target_id" && return 0
    sleep "$wait_s"
  done
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

target_id="$(layout_target_id "$command_line")"

# Tear down any leftover BetterDisplay virtual FIRST. A prior `d remote`
# session can leave a virtual display as macOS's only "main" display; placing
# the physical display while that phantom is present fails. Discarding up
# front clears that stuck state before we try anything else.
run_layout_discard "$layout_path"

# Make sure the physical target display is actually present. If a remote
# session or a flaky reconnect left it offline, ask BetterDisplay to bring it
# back before giving up.
if [[ -n "$target_id" ]] && ! displayplacer_has_id "$target_id"; then
  printf 'Display %s not present; asking BetterDisplay to reconnect displays...\n' "$target_id" >&2
  reconnect_displays "$target_id"
fi

if [[ -n "$target_id" ]] && ! displayplacer_has_id "$target_id"; then
  cat >&2 <<EOF
Error: target display $target_id is not connected.

Any leftover virtual display was discarded and a reconnect was attempted, but
macOS still does not see $target_id. This is a physical-layer problem, not a
layout problem:

  - Power-cycle the display: unplug its power for ~30s, then reconnect.
  - Move the cable to a different Thunderbolt/USB-C port on the Mac.
  - For an Apple Studio Display, a power-cycle resets its internal firmware.

Re-run \`d restore\` once the display is showing again.
EOF
  exit 1
fi

current_command="$(displayplacer list | awk '/^displayplacer / { command = $0 } END { print command }')"
if [[ -n "$current_command" && "$command_line" == "$current_command" ]]; then
  cat <<EOF
Already at requested local display layout.

Layout: $layout_path
EOF
  exit 0
fi

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
