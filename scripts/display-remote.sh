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

layout_serial_ids() {
  grep -Eo 's[0-9]+' <<<"$1" | sort -u
}

missing_serial_ids() {
  local command="$1"
  local current_list="$2"
  local serial

  while IFS= read -r serial; do
    [[ -z "$serial" ]] && continue
    if [[ "$current_list" != *"Serial screen id: $serial"* ]]; then
      printf '%s\n' "$serial"
    fi
  done < <(layout_serial_ids "$command")
}

betterdisplay_virtual_tag_for_serial() {
  local serial="$1"

  betterdisplaycli get -identifiers | awk -v wanted_serial="$serial" '
    /"deviceType" : "VirtualScreen"/ {
      in_virtual_screen = 1
      serial_matches = 0
      tag_id = ""
    }

    in_virtual_screen && $0 ~ "\"serial\" : \"" wanted_serial "\"" {
      serial_matches = 1
    }

    in_virtual_screen && tag_id == "" && /"tagID" :/ {
      tag_id = $0
      gsub(/.*"tagID" : "/, "", tag_id)
      gsub(/".*/, "", tag_id)
    }

    /^}/ || /^},/ {
      if (in_virtual_screen && serial_matches && tag_id != "") {
        print tag_id
        exit
      }
      in_virtual_screen = 0
      serial_matches = 0
      tag_id = ""
    }
  '
}

connect_betterdisplay_virtual_serial() {
  local serial="$1"
  local tag_id

  tag_id="$(betterdisplay_virtual_tag_for_serial "$serial")"
  if [[ -z "$tag_id" ]]; then
    return 1
  fi

  open "BetterDisplay://set?tagID=$tag_id&connected=on"
}

wait_for_layout_serials() {
  local command="$1"
  local attempts="${2:-8}"
  local current_list

  for ((i = 0; i < attempts; i++)); do
    current_list="$(displayplacer list)"
    if [[ -z "$(missing_serial_ids "$command" "$current_list")" ]]; then
      return 0
    fi
    sleep 1
  done

  return 1
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

if layout_has_directive "$layout_path" "betterdisplay:[[:space:]]*connect-all-displays"; then
  if ! command -v betterdisplaycli >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Error: this layout requires BetterDisplay, but betterdisplaycli was not found.

Install it with:
  brew install waydabber/betterdisplay/betterdisplaycli
EOF
    exit 127
  fi

  create_args="$(layout_directive_value "$layout_path" "betterdisplay-create:")"

  # Defensive: discard any existing virtual screen(s) matching the layout's
  # create name. Prevents BetterDisplay from accumulating stale duplicates
  # across sessions (each Screens cycle starts with a fresh virtual screen).
  if [[ -n "$create_args" ]]; then
    virtual_name="$(grep -oE -- '--virtualScreenName=[^ ]+' <<<"$create_args" | head -n1 | sed 's/--virtualScreenName=//')"
    if [[ -n "$virtual_name" ]]; then
      while betterdisplaycli discard --type=VirtualScreen --name="$virtual_name" >/dev/null 2>&1; do
        sleep 0.5
      done
    fi
  fi

  if [[ -n "$create_args" ]]; then
    # The create arguments come from the local layout file. They intentionally
    # use shell-style argument splitting so BetterDisplay receives each flag.
    # shellcheck disable=SC2086
    betterdisplaycli create $create_args >/dev/null 2>&1 || true
    sleep 1
  fi

  betterdisplaycli perform --connectAllDisplays >/dev/null 2>&1 || true
  sleep 1

  current_list="$(displayplacer list)"
  if [[ -n "$(missing_serial_ids "$command_line" "$current_list")" ]]; then
    while IFS= read -r serial_id; do
      [[ -z "$serial_id" ]] && continue
      connect_betterdisplay_virtual_serial "${serial_id#s}" || true
    done < <(missing_serial_ids "$command_line" "$current_list")
    sleep 2
  fi

  if ! wait_for_layout_serials "$command_line"; then
    cat >&2 <<EOF
Error: BetterDisplay did not expose every display required by this layout.

Missing serial ids:
$(missing_serial_ids "$command_line" "$(displayplacer list)")

Layout: $layout_path
EOF
    exit 1
  fi
fi

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
