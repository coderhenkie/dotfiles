#!/usr/bin/env bash
# ==========================================
# Monitor Menu (Rofi)
# ==========================================
# Switch between mirroring and side-by-side screens. Bound to $mod+p.
#   Extend   : the saved layout (autorandr profile `main`); asks left/right first if there is
#              no saved layout for these screens yet (scripts/monitor-layout.sh in kitty)
#   Mirror   : every screen shows the same picture (autorandr's built-in `common` profile)
#   Arrange  : choose again which screen is left / right (scripts/monitor-layout.sh)
# Workspaces follow automatically via the autorandr postswitch hook (scripts/workspaces.sh):
# 2 screens = workspaces 1-4 left, 5-10 right.

ICON_EXTEND=$'\U000F0380'   # nf-md-monitor_multiple
ICON_MIRROR=$'\U000F0379'   # nf-md-monitor
ICON_ARRANGE=$'\U000F04E1'  # nf-md-swap_horizontal

EXTEND="$ICON_EXTEND  Extend (side by side)"
MIRROR="$ICON_MIRROR  Mirror"
ARRANGE="$ICON_ARRANGE  Choose left / right…"

LAYOUT="$HOME/dotfiles/scripts/monitor-layout.sh"

notify() { command -v notify-send >/dev/null && notify-send -a "Display" -u low "Display" "$1"; }

N=$(xrandr --query | awk '$2 == "connected"' | wc -l)
if [ "$N" -lt 2 ]; then
    notify "Only one screen detected: nothing to switch."
    exit 0
fi

# Current mode: mirrored when every connected screen starts at the same position
POSITIONS=$(xrandr --query | awk '$2 == "connected" { for (f = 3; f <= NF; f++) if ($f ~ /^[0-9]+x[0-9]+\+/) { sub(/^[0-9]+x[0-9]+/, "", $f); print $f } }' | sort -u | wc -l)
if [ "$POSITIONS" -le 1 ]; then CURRENT="Mirror"; else CURRENT="Extend"; fi

choice=$(printf '%s\n' "$EXTEND" "$MIRROR" "$ARRANGE" \
    | rofi -dmenu -i -p "Screens" -mesg "$N screens detected · now: $CURRENT" \
        -theme-str 'window { width: 26%; } listview { lines: 3; }')

arrange() {
    kitty --title "Monitor Layout" -e bash -c "'$LAYOUT'; sleep 2"
}

case "$choice" in
    "$EXTEND")
        # Saved profile matches these screens -> load it; otherwise ask the order first
        if autorandr --detected 2>/dev/null | grep -qx main; then
            autorandr --load main
        else
            arrange
        fi
        ;;
    "$MIRROR")  autorandr --load common ;;
    "$ARRANGE") arrange ;;
esac
