#!/usr/bin/env bash
# ==========================================
# Thorium Browser Launcher
# ==========================================
# Launcher for Rofi entry and default browser. Before Thorium starts, applies Color Engine colors
# that are waiting for Dark Reader (its storage is locked while Thorium runs: darkreader-theme.js).
#
# Usage: thorium-launch.sh [args...]

# No set -e: optional Dark Reader pre-launch sync must not prevent Thorium from starting.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

if have node; then
    node "$DOTFILES_DIR/scripts/darkreader-theme.js" pending >/dev/null 2>&1 || true
fi
exec "$HOME/.local/bin/thorium" "$@"
