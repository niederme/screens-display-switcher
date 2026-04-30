#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title display restore
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName Screens Display Switcher
# @raycast.description Restore the local display layout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$ROOT_DIR/scripts/display-restore.sh"
