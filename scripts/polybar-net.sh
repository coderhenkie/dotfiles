#!/usr/bin/env bash
# ==========================================
# Polybar Network Connection Status Module
# ==========================================
# Replaces the nm-applet tray icon (left-click opens menu-wifi.sh, right-click opens nmtui).
#   cable plugged in : "󰈀 Wired"
#   Wi-Fi connected  : "<signal icon> <SSID>"
#   Wi-Fi outside NM : "<signal icon> <SSID> (unmanaged)" (ifupdown Wi-Fi: menu-wifi.sh can't manage it)
#   nothing          : muted "disconnected" icon (Wi-Fi icon if the machine has Wi-Fi, else cable icon)
#
# Usage: polybar-net.sh [-h|--help]

# No set -e: nmcli/iw/grep return non-zero when disconnected.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

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

has_wifi=false
wifi_devs=()
for dev in /sys/class/net/*; do
    [ -e "$dev" ] || continue
    name=${dev##*/}
    [ "$name" = lo ] && continue
    if [ -d "$dev/wireless" ] || [ -e "$dev/phy80211" ]; then
        has_wifi=true
        wifi_devs+=("$name")
        continue
    fi
    # Physical NICs only (skip docker/veth/bridges/VPN tunnels, which have no device link)
    [ -e "$dev/device" ] || continue
    if [ "$(cat "$dev/operstate" 2>/dev/null || true)" = up ]; then
        echo "󰈀 %{F-}Wired"
        exit 0
    fi
done

if $has_wifi; then
    line=$(nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan no 2>/dev/null | grep -m1 '^yes:' || true)
    # Fallback for Wi-Fi that NetworkManager doesn't manage (e.g. set up in /etc/network/interfaces
    # by the Debian installer, which NM ignores): ask the kernel via iw. Same "yes:SIGNAL:SSID" shape,
    # marked "(unmanaged)" so it doesn't look like normal Wi-Fi while the menu can't manage it.
    unmanaged=""
    if [ -z "$line" ]; then
        IW=$(command -v iw || echo /usr/sbin/iw)
        for d in "${wifi_devs[@]}"; do
            link=$("$IW" dev "$d" link 2>/dev/null) || continue
            ssid=$(sed -n 's/^\s*SSID: //p' <<< "$link")
            [ -n "$ssid" ] || continue
            dbm=$(sed -n 's/^\s*signal: \(-\?[0-9]*\).*/\1/p' <<< "$link")
            pct=$(( 2 * (${dbm:--100} + 100) )); [ "$pct" -gt 100 ] && pct=100; [ "$pct" -lt 0 ] && pct=0
            line="yes:$pct:$ssid"
            # Only a marker when NM really doesn't manage the card (or isn't running): NM's scan list can
            # also briefly miss the connected network right after connecting or resuming
            state=$(nmcli -t -f DEVICE,STATE dev 2>/dev/null | awk -F: -v d="$d" '$1 == d { print $2 }')
            case "$state" in
                ""|unmanaged) unmanaged=" %{F$muted}(unmanaged)%{F-}" ;;
            esac
            break
        done
    fi
    if [ -n "$line" ]; then
        signal=$(cut -d: -f2 <<< "$line")
        [[ "$signal" =~ ^[0-9]+$ ]] || signal=0   # nmcli can leave SIGNAL empty right after connecting
        ssid=$(cut -d: -f3- <<< "$line" | sed 's/\\:/:/g')
        icons=(󰤯 󰤟 󰤢 󰤥 󰤨)
        idx=$(( signal / 20 )); [ "$idx" -gt 4 ] && idx=4
        [ "${#ssid}" -gt 20 ] && ssid="${ssid:0:17}..."
        echo "${icons[$idx]} %{F-}$ssid$unmanaged"
    else
        echo "%{F$muted}󰤮%{F-}"
    fi
else
    echo "%{F$muted}󰈂%{F-}"
fi
