#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Display: Restore Local
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName Screens Display Switcher
# @raycast.description Restore the normal local display layout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$ROOT_DIR/scripts/restore-local.sh"
