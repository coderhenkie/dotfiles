#!/usr/bin/env bash
# ==========================================
# Polybar Bluetooth Status Module
# ==========================================
# Replaces the blueman tray icon:
#   no args : print status — "%{F<muted>}󰂲%{F-}" when off, "󰂯" when on, "󰂱 <device>" when connected
#   toggle  : power the adapter on/off (right-click; left-click opens scripts/menu-bluetooth.sh)
# Prints nothing when the machine has no Bluetooth controller, so the module hides itself.
#
# Usage: polybar-bluetooth.sh [toggle|-h|--help]

# No set -e: bluetoothctl exits non-zero when the controller is off or absent.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

[ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] || exit 0
have bluetoothctl || exit 0

muted=$(awk -F' *= *' '/^muted[[:space:]]*=/ { print $2; exit }' "$THEME_CACHE/polybar.ini" 2>/dev/null || true)
if ! is_hex_color "$muted"; then
    # shellcheck disable=SC2119  # theme_load without argument loads active theme
    if theme_load 2>/dev/null; then
        # shellcheck disable=SC2154  # bg and fg are set by theme_load
        r=$(( (16#${bg:1:2} * 52 + 16#${fg:1:2} * 48 + 50) / 100 ))
        g=$(( (16#${bg:3:2} * 52 + 16#${fg:3:2} * 48 + 50) / 100 ))
        b=$(( (16#${bg:5:2} * 52 + 16#${fg:5:2} * 48 + 50) / 100 ))
        printf -v muted '#%02x%02x%02x' "$r" "$g" "$b"
    else
        muted="#646a70"
    fi
fi

if [ "${1:-}" = "toggle" ]; then
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        bluetoothctl power off >/dev/null
    else
        rfkill unblock bluetooth 2>/dev/null || true
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
