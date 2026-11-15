#!/usr/bin/env bash
# ==========================================
# Obsidian Desktop App Launcher
# ==========================================
# Launcher for Rofi entry, `obsidian-app`, and obsidian:// links.
# The app has its own Sync, so headless sync (obsidian-sync.sh) is paused first; its daemon starts it
# again once the app is closed. Already running? Hand over links/files and focus it.
#
# Usage: obsidian-app.sh [args...]

# No set -e: pgrep returns non-zero when Obsidian is not yet running.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

APPIMAGE="$HOME/appimages/obsidian.appimage"
[ -x "$APPIMAGE" ] || die "Obsidian AppImage not found at $APPIMAGE."

if pgrep -x obsidian >/dev/null 2>&1; then
    [ $# -gt 0 ] && setsid "$APPIMAGE" "$@" >/dev/null 2>&1 < /dev/null &
    i3-msg -q '[class="(?i)obsidian"] focus' || true
else
    "$DOTFILES_DIR/scripts/obsidian-sync.sh" pause
    exec "$APPIMAGE" "$@"
fi
