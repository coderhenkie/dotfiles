#!/usr/bin/env bash
# Polybar connection status (replaces the nm-applet tray icon; click opens nmtui).
#   cable plugged in : "󰈀 Wired"
#   Wi-Fi connected  : "<signal icon> <SSID>"
#   nothing          : muted "disconnected" icon (Wi-Fi icon if the machine has Wi-Fi, else cable icon)

muted=$(awk -F' *= *' '/^muted/ { print $2; exit }' ~/.cache/theme/polybar.ini 2>/dev/null)
muted=${muted:-#646a70}

has_wifi=false
for dev in /sys/class/net/*; do
    name=${dev##*/}
    [ "$name" = lo ] && continue
    if [ -d "$dev/wireless" ] || [ -e "$dev/phy80211" ]; then
        has_wifi=true
        continue
    fi
    # Physical NICs only (skip docker/veth/bridges/VPN tunnels, which have no device link)
    [ -e "$dev/device" ] || continue
    if [ "$(cat "$dev/operstate" 2>/dev/null)" = up ]; then
        echo "󰈀 %{F-}Wired"
        exit 0
    fi
done

if $has_wifi; then
    line=$(nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan no 2>/dev/null | grep -m1 '^yes:')
    if [ -n "$line" ]; then
        signal=$(cut -d: -f2 <<< "$line")
        ssid=$(cut -d: -f3- <<< "$line" | sed 's/\\:/:/g')
        icons=(󰤯 󰤟 󰤢 󰤥 󰤨)
        idx=$(( signal / 20 )); [ "$idx" -gt 4 ] && idx=4
        [ "${#ssid}" -gt 20 ] && ssid="${ssid:0:17}..."
        echo "${icons[$idx]} %{F-}$ssid"
    else
        echo "%{F$muted}󰤮%{F-}"
    fi
else
    echo "%{F$muted}󰈂%{F-}"
fi
