#!/usr/bin/env bash

# ==========================================
# Polybar Calendar Popup (yad)
# ==========================================
# Click the clock to toggle a small GTK calendar (themed by ~/.cache/theme/gtk.css)
# in the top-right corner of the focused monitor, just below the top Polybar.
# Use the arrows at the top to go to the previous/next month (and year).
# Click the clock again or press Esc to close it.

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/polybar-calendar.pid"
WIDTH=300
BAR_HEIGHT=27
GAP=8

# Toggle: a second click closes the open calendar
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
    exit 0
fi

if ! command -v yad >/dev/null 2>&1; then
    notify-send -a "Calendar" -u critical "Calendar" "Missing dependency: yad (sudo nala install yad)" 2>/dev/null
    exit 1
fi

# Top-right corner of the focused monitor, just below the top Polybar
POS_X=10
POS_Y=$((BAR_HEIGHT + GAP))
RECT=$(i3-msg -t get_workspaces 2>/dev/null | jq -r '.[] | select(.focused) | .rect | "\(.x) \(.y) \(.width)"' 2>/dev/null)
if [ -n "$RECT" ]; then
    read -r RX RY RW <<< "$RECT"
    # The workspace rect already excludes the dock bars, so RY is the bottom edge of the top bar
    POS_X=$((RX + RW - WIDTH - GAP))
    POS_Y=$((RY + GAP))
fi

EXTRA_OPTS=()
yad --help-all 2>/dev/null | grep -q -- '--close-on-unfocus' && EXTRA_OPTS+=(--close-on-unfocus)

yad --calendar \
    --title="Calendar" --class="Calendar" \
    --undecorated --skip-taskbar --fixed --on-top --no-buttons \
    --width="$WIDTH" --posx="$POS_X" --posy="$POS_Y" \
    --show-weeks \
    "${EXTRA_OPTS[@]}" >/dev/null 2>&1 &
echo $! > "$PID_FILE"
wait $!
rm -f "$PID_FILE"
