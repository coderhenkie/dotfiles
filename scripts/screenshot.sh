#!/usr/bin/env bash
# ==========================================
# Area Screenshot (maim + slop + xclip)
# ==========================================
# Lets you drag a rectangle (or click a window) with the mouse, saves the
# result as a PNG in ~/Pictures and copies it to the clipboard so it can be
# pasted anywhere. Press Esc or right-click to cancel.
# Bound to Control+Shift+s in i3/hotkeys.default.
#
# Usage: screenshot.sh [-h|--help]

# No set -e: maim exits non-zero when the selection is cancelled with Esc or right-click.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need maim xclip

PICTURES_DIR=$(xdg-user-dir PICTURES 2>/dev/null || true)
# xdg-user-dir falls back to $HOME when no Pictures dir is configured
if [ -z "$PICTURES_DIR" ] || [ "$PICTURES_DIR" = "$HOME" ]; then
    PICTURES_DIR="$HOME/Pictures"
fi
mkdir -p "$PICTURES_DIR"

FILE="$PICTURES_DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# Use the Color Engine accent for the selection rectangle
# shellcheck disable=SC2119  # theme_load without argument loads active theme
theme_load 2>/dev/null || accent="#bd93f9"
ACCENT="${accent#\#}"
SLOP_COLOR=$(awk -v r=$((16#${ACCENT:0:2})) -v g=$((16#${ACCENT:2:2})) -v b=$((16#${ACCENT:4:2})) \
    'BEGIN { printf "%.3f,%.3f,%.3f,0.25", r/255, g/255, b/255 }')

# -s: select area (drag, or click a window), -u: hide cursor, -l: translucent
# highlight in the accent color. maim exits non-zero when the selection is cancelled.
if ! maim -s -u -l -c "$SLOP_COLOR" -b 2 "$FILE" 2>/dev/null; then
    rm -f "$FILE"
    exit 0
fi

xclip -selection clipboard -t image/png -i "$FILE"

notify -a "Screenshot" -i "$FILE" "Screenshot saved" "${FILE/#$HOME/\~}  (copied to clipboard)"
