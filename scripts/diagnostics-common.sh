#!/usr/bin/env bash

# Shared, best-effort diagnostics for the display switching scripts.
# Logging must never prevent a requested display operation from running.

DISPLAY_SWITCHER_DIAG_DIR="${DISPLAY_SWITCHER_DIAG_DIR:-$HOME/Library/Logs/screens-display-switcher}"
DISPLAY_SWITCHER_EVENT_LOG="$DISPLAY_SWITCHER_DIAG_DIR/events.log"
DISPLAY_SWITCHER_ACTION="${DISPLAY_SWITCHER_ACTION:-unknown}"
DISPLAY_SWITCHER_LAYOUT="${DISPLAY_SWITCHER_LAYOUT:-}"
DISPLAY_SWITCHER_STARTED_AT=""

diagnostics_timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

diagnostics_sanitize() {
  printf '%s' "$*" | tr '\n\t' '  '
}

diagnostics_parent_command() {
  ps -p "$PPID" -o command= 2>/dev/null || true
}

diagnostics_event() {
  local phase="${1:-event}"
  shift || true
  local detail
  detail="$(diagnostics_sanitize "$*")"

  mkdir -p "$DISPLAY_SWITCHER_DIAG_DIR" 2>/dev/null || return 0
  printf '%s\taction=%s\tphase=%s\tpid=%s\tppid=%s\tparent=%s\tlayout=%s\tdetail=%s\n' \
    "$(diagnostics_timestamp)" \
    "$(diagnostics_sanitize "$DISPLAY_SWITCHER_ACTION")" \
    "$(diagnostics_sanitize "$phase")" \
    "$$" \
    "$PPID" \
    "$(diagnostics_sanitize "$(diagnostics_parent_command)")" \
    "$(diagnostics_sanitize "$DISPLAY_SWITCHER_LAYOUT")" \
    "$detail" >>"$DISPLAY_SWITCHER_EVENT_LOG" 2>/dev/null || true
}

diagnostics_display_state() {
  local state="displayplacer-unavailable"
  if command -v displayplacer >/dev/null 2>&1; then
    state="$(displayplacer list 2>/dev/null | awk '
      /^Serial screen id:/ { serial = $0; sub(/^Serial screen id: /, "", serial) }
      /^Resolution:/ { resolution = $0; sub(/^Resolution: /, "", resolution) }
      /^Enabled:/ { enabled = $0; sub(/^Enabled: /, "", enabled) }
      /^displayplacer / { command = $0 }
      END {
        printf "serial=%s resolution=%s enabled=%s command=%s",
          serial, resolution, enabled, command
      }
    ')"
  fi
  diagnostics_event "state" "$state"
}

diagnostics_begin() {
  DISPLAY_SWITCHER_ACTION="$1"
  DISPLAY_SWITCHER_LAYOUT="${2:-}"
  DISPLAY_SWITCHER_STARTED_AT="$(date +%s)"
  diagnostics_event "begin" "argv=$(diagnostics_sanitize "$0 $*")"
  diagnostics_display_state
}

diagnostics_finish() {
  local exit_code="$1"
  local elapsed="unknown"
  if [[ -n "$DISPLAY_SWITCHER_STARTED_AT" ]]; then
    elapsed="$(( $(date +%s) - DISPLAY_SWITCHER_STARTED_AT ))s"
  fi
  diagnostics_display_state
  diagnostics_event "end" "exit=$exit_code elapsed=$elapsed"
}

