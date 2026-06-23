#!/usr/bin/env bash
set -uo pipefail

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MINUTES="${1:-60}"
OUTPUT_ROOT="${DISPLAY_SWITCHER_DIAGNOSTICS_OUTPUT_DIR:-$HOME/Desktop}"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BUNDLE_DIR="$OUTPUT_ROOT/screens-display-switcher-diagnostics-$STAMP"
ARCHIVE="$BUNDLE_DIR.tar.gz"
EVENT_LOG="${DISPLAY_SWITCHER_DIAG_DIR:-$HOME/Library/Logs/screens-display-switcher}/events.log"

usage() {
  cat <<'EOF'
Usage:
  collect-diagnostics.sh [minutes]

Collects current display state, recent display/hot-plug logs, login-item
information, and switcher invocation history into a timestamped archive.
Defaults to the last 60 minutes.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]] || [[ "$MINUTES" -lt 1 ]]; then
  printf 'Error: minutes must be a positive integer.\n' >&2
  exit 2
fi

mkdir -p "$BUNDLE_DIR"

capture() {
  local output="$1"
  shift
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
  } >"$BUNDLE_DIR/$output" 2>&1 || true
}

{
  printf 'Collected: %s\n' "$(date)"
  printf 'Host: %s\n' "$(scutil --get ComputerName 2>/dev/null || hostname)"
  printf 'Window: last %s minutes\n' "$MINUTES"
  printf 'Repository: %s\n' "$ROOT_DIR"
  printf 'Revision: %s\n' "$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf '\nImportant privacy note: this bundle contains process command lines and macOS display logs.\n'
} >"$BUNDLE_DIR/README.txt"

capture "system.txt" sh -c 'date; uptime; sw_vers; uname -a; last reboot | head -n 5'
capture "displayplacer.txt" displayplacer list
capture "system-profiler.txt" system_profiler SPDisplaysDataType SPThunderboltDataType SPUSBDataType SPAudioDataType SPCameraDataType -detailLevel full
capture "processes.txt" sh -c "ps axo pid,ppid,lstart,etime,state,command | grep -Ei 'BetterDisplay|display-(remote|restore)|raycast-display|displayplacer|WindowServer' | grep -v grep"
capture "login-items.txt" sh -c "sfltool dumpbtm 2>/dev/null | grep -i -C 5 BetterDisplay"
capture "ioreg-display.txt" sh -c "ioreg -lw0 | grep -Ei -C 3 'Studio Display|DisplayVendorID|DisplayProductID|IODPPort|DisplayPort@0'"

/usr/bin/log show --last "${MINUTES}m" --style compact \
  --predicate '(process == "kernel" OR process == "WindowServer") AND (eventMessage CONTAINS[c] "DisplayPort" OR eventMessage CONTAINS[c] "hotplug" OR eventMessage CONTAINS[c] "StudioDisplay" OR eventMessage CONTAINS[c] "unplug" OR eventMessage CONTAINS[c] "HPDMonitor")' \
  >"$BUNDLE_DIR/display-hotplug.log" 2>&1 || true

/usr/bin/log show --last "${MINUTES}m" --style compact \
  --predicate 'process == "BetterDisplay" OR process == "Raycast" OR process == "displayplacer"' \
  >"$BUNDLE_DIR/display-tools.log" 2>&1 || true

if [[ -f "$EVENT_LOG" ]]; then
  cp "$EVENT_LOG" "$BUNDLE_DIR/switcher-events.log"
else
  printf 'No switcher event log exists yet.\n' >"$BUNDLE_DIR/switcher-events.log"
fi

cp "$ROOT_DIR/layouts/local.displayplacer" "$BUNDLE_DIR/local.displayplacer" 2>/dev/null || true
cp "$ROOT_DIR/layouts/remote.displayplacer" "$BUNDLE_DIR/remote.displayplacer" 2>/dev/null || true

tar -czf "$ARCHIVE" -C "$OUTPUT_ROOT" "$(basename "$BUNDLE_DIR")"
rm -rf "$BUNDLE_DIR"
printf '%s\n' "$ARCHIVE"
