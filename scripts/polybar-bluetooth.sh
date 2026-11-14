#!/usr/bin/env bash
# Polybar Bluetooth status (replaces the blueman tray icon).
#   no args : print status — "%{F<muted>}󰂲%{F-}" when off, "󰂯" when on, "󰂱 <device>" when connected
#   toggle  : power the adapter on/off (right-click; left-click opens scripts/menu-bluetooth.sh)
# Prints nothing when the machine has no Bluetooth controller, so the module hides itself.

muted=$(awk -F' *= *' '/^muted/ { print $2; exit }' ~/.cache/theme/polybar.ini 2>/dev/null)
muted=${muted:-#646a70}

[ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] || exit 0

if [ "$1" = "toggle" ]; then
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        bluetoothctl power off >/dev/null
    else
        rfkill unblock bluetooth 2>/dev/null
        bluetoothctl power on >/dev/null
    fi
    exit 0
fi

if ! bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
    echo "%{F$muted}󰂲%{F-}"
    exit 0
fi

device=$(bluetoothctl devices Connected 2>/dev/null | head -n 1 | cut -d' ' -f3-)
if [ -n "$device" ]; then
    echo "󰂱 ${device:0:20}"
else
    echo "󰂯"
fi
