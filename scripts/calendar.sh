#!/usr/bin/env bash
# ==========================================
# Polybar Calendar Popup (yad)
# ==========================================
# Click the clock to toggle a small GTK calendar (themed by ~/.cache/theme/gtk.css)
# in the top-right corner of the focused monitor, just below the top Polybar.
# Use the arrows at the top to go to the previous/next month (and year).
# Click the clock again or press Esc to close it.
#
# Usage: calendar.sh [-h|--help]

# No set -e: yad exits non-zero when closed with Esc or unfocused.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

PID_FILE="$(runtime_dir)/polybar-calendar.pid"
WIDTH=300
BAR_HEIGHT=27
GAP=8

# Toggle: a second click closes the open calendar
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        exit 0
    fi
fi

need yad

# Top-right corner of the focused monitor, just below the top Polybar
POS_X=10
POS_Y=$((BAR_HEIGHT + GAP))
RECT=$(i3-msg -t get_workspaces 2>/dev/null | jq -r '.[] | select(.focused) | .rect | "\(.x) \(.y) \(.width)"' 2>/dev/null || true)
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
wait $! || true
rm -f "$PID_FILE"
