#!/usr/bin/env bash

# ==========================================
# Area Screenshot (maim + slop + xclip)
# ==========================================
# Lets you drag a rectangle (or click a window) with the mouse, saves the
# result as a PNG in ~/Pictures and copies it to the clipboard so it can be
# pasted anywhere. Press Esc or right-click to cancel.
# Bound to Control+Shift+t in i3/hotkeys.default.

for dep in maim xclip; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        notify-send -a "Screenshot" -u critical "Screenshot" "Missing dependency: $dep (sudo nala install maim xclip)" 2>/dev/null
        exit 1
    fi
done

PICTURES_DIR=$(xdg-user-dir PICTURES 2>/dev/null)
# xdg-user-dir falls back to $HOME when no Pictures dir is configured
if [ -z "$PICTURES_DIR" ] || [ "$PICTURES_DIR" = "$HOME" ]; then
    PICTURES_DIR="$HOME/Pictures"
fi
mkdir -p "$PICTURES_DIR"

FILE="$PICTURES_DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# Use the Color Engine accent for the selection rectangle
ACCENT=$(sed -n 's/^accent=#//p' "$HOME/.cache/theme/current.theme" 2>/dev/null)
[[ "$ACCENT" =~ ^[0-9A-Fa-f]{6}$ ]] || ACCENT="bd93f9"
SLOP_COLOR=$(awk -v r=$((16#${ACCENT:0:2})) -v g=$((16#${ACCENT:2:2})) -v b=$((16#${ACCENT:4:2})) \
    'BEGIN { printf "%.3f,%.3f,%.3f,0.25", r/255, g/255, b/255 }')

# -s: select area (drag, or click a window), -u: hide cursor, -l: translucent
# highlight in the accent color. maim exits non-zero when the selection is cancelled.
if ! maim -s -u -l -c "$SLOP_COLOR" -b 2 "$FILE" 2>/dev/null; then
    rm -f "$FILE"
    exit 0
fi

xclip -selection clipboard -t image/png -i "$FILE"

notify-send -a "Screenshot" -i "$FILE" "Screenshot saved" "${FILE/#$HOME/\~}  (copied to clipboard)" 2>/dev/null || true
