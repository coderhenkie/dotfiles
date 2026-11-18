#!/usr/bin/env bash
# ==========================================
# Discord (web app in an isolated Thorium profile)
# ==========================================
# Runs Discord's web app in its own Thorium window with a separate profile, so it never
# sees the normal browser profile (cookies, history, logins). Chromium's sandbox keeps it
# away from your files and processes, which the desktop app (Electron) would not.
# The profile lives outside the repo ($XDG_DATA_HOME/discord-web) and is never tracked.
# Already running? Focus the window instead of starting a second one.
#
# Usage: discord.sh [-h|--help]

# No set -e: pgrep/i3-msg return non-zero when Discord is not running yet.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

THORIUM="$HOME/.local/bin/thorium"
[ -x "$THORIUM" ] || die "Thorium not found at $THORIUM (run setup.sh)."

PROFILE="${XDG_DATA_HOME:-$HOME/.local/share}/discord-web"
mkdir -p "$PROFILE"
chmod 700 "$PROFILE"

if pgrep -f -- "--user-data-dir=$PROFILE" >/dev/null 2>&1; then
    i3-msg -q '[class="^discord-web$"] focus' || true
    exit 0
fi

# --class sets the X11 WM_CLASS, so i3 and picom can target this window.
exec "$THORIUM" \
    --user-data-dir="$PROFILE" \
    --class=discord-web \
    --app=https://discord.com/app \
    --no-default-browser-check \
    --no-first-run
