#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title d diagnostics
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🩺
# @raycast.packageName Screens Display Switcher
# @raycast.description Collect recent display diagnostics on the Desktop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$ROOT_DIR/scripts/collect-diagnostics.sh" 60

