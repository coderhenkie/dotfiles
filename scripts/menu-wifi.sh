#!/usr/bin/env bash
# ==========================================
# Wi-Fi / Network Menu (Rofi + NetworkManager)
# ==========================================
# Opened by clicking the network icon in the bottom Polybar (right-click opens nmtui).
# Lists nearby Wi-Fi networks (connected one checked, lock = password needed); pick one
# to connect (asks for the password only for new secured networks). Also: Wi-Fi on/off,
# rescan, disconnect, hidden network, and the GTK editor (nm-connection-editor) for
# advanced settings (static IP, DNS, VPN). Themed via ~/.cache/theme/rofi.rasi like every
# other menu-*.sh.
#
# Usage: menu-wifi.sh [-h|--help]

# No set -e: rofi returns non-zero on Esc/cancel and nmcli returns non-zero when a connection fails.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need nmcli rofi
i3_env

ICON_OFF=$'\U000F05AA'      # nf-md-wifi_off
ICON_WIRED=$'\U000F0200'    # nf-md-ethernet
ICON_LOCK=$'\U000F033E'     # nf-md-lock
ICON_CHECK=$'\U000F012C'    # nf-md-check
ICON_SCAN=$'\U000F0450'     # nf-md-refresh
ICON_DISC=$'\U000F0156'     # nf-md-close
ICON_HIDDEN=$'\U000F0415'   # nf-md-plus
ICON_SETTINGS=$'\U000F0493' # nf-md-cog
ICON_TUI=$'\U000F018D'      # nf-md-console
SIGNAL=($'\U000F092F' $'\U000F091F' $'\U000F0922' $'\U000F0925' $'\U000F0928') # nf-md-wifi_strength_0..4

notify_net() { notify -a "Network" "$@"; }

rofi_menu() { # $1 prompt, $2 lines; options on stdin; prints the chosen index
    rofi -dmenu -i -format i -p "$1" -theme-str "window { width: 30%; } listview { lines: $2; }"
}

ask() { # $1 prompt, [$2 = password] -> typed text
    local extra=()
    [ "${2:-}" = password ] && extra=(-password)
    rofi -dmenu -p "$1" "${extra[@]}" -theme-str 'window { width: 30%; } listview { lines: 0; } entry { placeholder: ""; }' < /dev/null
}

wifi_dev=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')
wired=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$2 == "ethernet" && $3 == "connected" { print $1; exit }')

# Connect using PSK over an anonymous fd / stdin so the password never appears in ps/cmdline.
has_profile() { # $1 ssid -> exit 0 when a saved Wi-Fi profile with that name exists
    # nmcli -t escapes ':' and '\\' in names, so escape the SSID the same way before comparing
    local esc="${1//\\/\\\\}"
    esc="${esc//:/\\:}"
    nmcli -t -f NAME,TYPE con show 2>/dev/null | grep -Fxq -- "$esc:802-11-wireless"
}

connect_with_psk() { # $1 ssid, $2 pass, [$3 = hidden], [$4 = security from nmcli]
    # The password never goes on nmcli's command line (visible in ps / /proc/*/cmdline): it is
    # handed over through a file descriptor (`passwd-file`, see `man nmcli`, `connection up`).
    local ssid="$1" pass="$2" hidden="${3:-}" security="${4:-}" key_mgmt=wpa-psk
    if ! has_profile "$ssid"; then
        # WPA3-only networks need SAE; mixed WPA2/WPA3 and WPA2 use WPA-PSK
        [[ "$security" == *WPA3* && "$security" != *WPA2* && "$security" != *WPA1* ]] && key_mgmt=sae
        nmcli con add type wifi con-name "$ssid" ssid "$ssid" \
            ${hidden:+802-11-wireless.hidden yes} wifi-sec.key-mgmt "$key_mgmt" >/dev/null 2>&1 || return 1
    fi
    nmcli con up id "$ssid" ${wifi_dev:+ifname "$wifi_dev"} \
        passwd-file /dev/fd/3 3<<<"802-11-wireless-security.psk:$pass" 2>&1
}

connect() { # $1 ssid, $2 security
    local ssid="$1" security="$2" pass out rc had_profile=no
    if has_profile "$ssid"; then
        had_profile=yes
        out=$(nmcli con up id "$ssid" 2>&1) && { notify_net "Connected" "$ssid"; return; }
        # Saved password may be outdated: ask again below
    fi
    if [ -n "$security" ] && [ "$security" != "--" ]; then
        pass=$(ask "Password for $ssid" password) || return
        [ -z "$pass" ] && return
        out=$(connect_with_psk "$ssid" "$pass" "" "$security")
        rc=$?
    else
        out=$(nmcli dev wifi connect "$ssid" ${wifi_dev:+ifname "$wifi_dev"} 2>&1)
        rc=$?
    fi
    if [ "$rc" -eq 0 ]; then
        notify_net "Connected" "$ssid"
    else
        # Don't leave a broken new profile behind; an existing one (with its own IP/DNS settings) stays
        [ "$had_profile" = no ] && { nmcli con delete id "$ssid" >/dev/null 2>&1 || true; }
        notify_net -u critical "Could not connect to $ssid" "${out#Error: }"
    fi
}

main() {
    local rows=() actions=() net_inuse=() net_sec=() net_ssid=() rescan="${1:-no}"

    if [ -n "$wired" ]; then
        rows+=("$ICON_WIRED  Wired ($wired) connected"); actions+=(none)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    fi

    if [ -z "$wifi_dev" ]; then
        rows+=("$ICON_OFF  No Wi-Fi adapter"); actions+=(none)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    elif [ "$(nmcli radio wifi)" != "enabled" ]; then
        rows+=("$ICON_OFF  Wi-Fi is off: turn on"); actions+=(radio-on)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    else
        rows+=("$ICON_OFF  Turn Wi-Fi off"); actions+=(radio-off)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")

        # IN-USE:SIGNAL:SECURITY:SSID, strongest first, one row per SSID
        local line inuse signal security ssid seen="" icon
        while IFS= read -r line; do
            inuse=${line%%:*};    line=${line#*:}
            signal=${line%%:*};   line=${line#*:}
            security=${line%%:*}; ssid=${line#*:}
            ssid=${ssid//\\:/:}
            [ -z "$ssid" ] && continue
            grep -Fxq -- "$ssid" <<< "$seen" && continue
            seen+="$ssid"$'\n'
            icon=${SIGNAL[$(( signal >= 100 ? 4 : signal / 20 ))]}
            local mark="   " lock=""
            [ "$inuse" = "*" ] && mark="$ICON_CHECK "
            [ -n "$security" ] && [ "$security" != "--" ] && lock="  $ICON_LOCK"
            rows+=("$icon  $mark$ssid$lock"); actions+=(net)
            net_inuse+=("$inuse"); net_sec+=("$security"); net_ssid+=("$ssid")
        done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan "$rescan" 2>/dev/null \
                 | sort -t: -k2,2nr)

        rows+=("$ICON_SCAN  Rescan"); actions+=(rescan)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
        rows+=("$ICON_HIDDEN  Hidden network…"); actions+=(hidden)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    fi

    rows+=("$ICON_SETTINGS  Advanced settings (IP, DNS, VPN)…"); actions+=(editor)
    net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    rows+=("$ICON_TUI  Open nmtui"); actions+=(nmtui)
    net_inuse+=(""); net_sec+=(""); net_ssid+=("")

    local n=${#rows[@]} idx
    idx=$(printf '%s\n' "${rows[@]}" | rofi_menu "Network" $(( n > 12 ? 12 : n ))) || exit 0
    [ -z "$idx" ] && exit 0

    local action=${actions[$idx]}
    case "$action" in
        radio-on)  nmcli radio wifi on;  sleep 2; main yes ;;
        radio-off) nmcli radio wifi off; notify_net "Wi-Fi off" ;;
        rescan)    main yes ;;
        hidden)
            local ssid pass rc had_profile=no
            ssid=$(ask "Network name (SSID)") || exit 0
            [ -z "$ssid" ] && exit 0
            has_profile "$ssid" && had_profile=yes
            pass=$(ask "Password (empty = open)" password) || exit 0
            if [ -n "$pass" ]; then
                connect_with_psk "$ssid" "$pass" hidden >/dev/null 2>&1
                rc=$?
            else
                nmcli dev wifi connect "$ssid" hidden yes ${wifi_dev:+ifname "$wifi_dev"} >/dev/null 2>&1
                rc=$?
            fi
            if [ "$rc" -eq 0 ]; then
                notify_net "Connected" "$ssid"
            else
                [ "$had_profile" = no ] && { nmcli con delete id "$ssid" >/dev/null 2>&1 || true; }
                notify_net -u critical "Could not connect to $ssid"
            fi ;;
        editor)    setsid nm-connection-editor >/dev/null 2>&1 & ;;
        nmtui)     setsid kitty -e nmtui >/dev/null 2>&1 & ;;
        net)
            local inuse=${net_inuse[$idx]} security=${net_sec[$idx]} ssid=${net_ssid[$idx]}
            if [ "$inuse" = "*" ]; then
                local choice
                choice=$(printf '%s\n' "$ICON_DISC  Disconnect from $ssid" "$ICON_DISC  Forget $ssid" \
                    | rofi_menu "$ssid" 2) || exit 0
                case "$choice" in
                    0) nmcli dev disconnect "$wifi_dev" >/dev/null && notify_net "Disconnected" "$ssid" ;;
                    1) nmcli con delete id "$ssid" >/dev/null && notify_net "Forgot" "$ssid" ;;
                esac
            else
                connect "$ssid" "$security"
            fi ;;
    esac
}

main
