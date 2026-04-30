#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  install.sh [--install-deps]

Checks the local setup for screens-display-switcher.

Options:
  --install-deps   Install displayplacer with Homebrew if it is missing.
EOF
}

install_deps=false
missing_displayplacer=false

case "${1:-}" in
  "")
    ;;
  --install-deps)
    install_deps=true
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if ! command -v displayplacer >/dev/null 2>&1; then
  if [[ "$install_deps" == true ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      cat >&2 <<'EOF'
Error: Homebrew is not installed or not on PATH.
Install displayplacer manually after installing Homebrew:
  brew install displayplacer
EOF
      exit 127
    fi

    brew install displayplacer
  else
    missing_displayplacer=true
    cat <<'EOF'
displayplacer is not installed.

Install it with:
  brew install displayplacer

Or run:
  ./scripts/install.sh --install-deps
EOF
  fi
else
  printf 'displayplacer found: %s\n' "$(command -v displayplacer)"
fi

chmod +x "$ROOT_DIR"/scripts/*.sh
if [[ -d "$ROOT_DIR/raycast" ]]; then
  chmod +x "$ROOT_DIR"/raycast/*.sh
fi
mkdir -p "$ROOT_DIR/layouts"

if [[ "$missing_displayplacer" == true ]]; then
  cat <<'EOF'

Setup incomplete: install displayplacer, then rerun this script.
EOF
  exit 1
fi

cat <<EOF

Setup checked.

Next:
  ./scripts/capture-layout.sh local
  ./scripts/capture-layout.sh remote
  ./scripts/go-remote.sh
  ./scripts/restore-local.sh
EOF
