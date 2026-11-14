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

ICON_ON=$'\U000F05A9'       # nf-md-wifi
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

export DISPLAY="${DISPLAY:-:0}"

notify() { notify-send -a "Network" "$@"; }

rofi_menu() { # $1 prompt, $2 lines; options on stdin; prints the chosen index
    rofi -dmenu -i -format i -p "$1" -theme-str "window { width: 30%; } listview { lines: $2; }"
}

ask() { # $1 prompt, [$2 = password] -> typed text
    local extra=()
    [ "$2" = password ] && extra=(-password)
    rofi -dmenu -p "$1" "${extra[@]}" -theme-str 'window { width: 30%; } listview { lines: 0; } entry { placeholder: ""; }' < /dev/null
}

wifi_dev=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')
wired=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$2 == "ethernet" && $3 == "connected" { print $1; exit }')

connect() { # $1 ssid, $2 security
    local ssid="$1" security="$2" pass out
    if nmcli -t -f NAME,TYPE con show | grep -Fxq -- "$ssid:802-11-wireless"; then
        out=$(nmcli con up id "$ssid" 2>&1) && { notify "Connected" "$ssid"; return; }
        # Saved password may be outdated: ask again below
    fi
    if [ -n "$security" ] && [ "$security" != "--" ]; then
        pass=$(ask "Password for $ssid" password) || return
        [ -z "$pass" ] && return
        out=$(nmcli dev wifi connect "$ssid" password "$pass" ${wifi_dev:+ifname "$wifi_dev"} 2>&1)
    else
        out=$(nmcli dev wifi connect "$ssid" ${wifi_dev:+ifname "$wifi_dev"} 2>&1)
    fi
    if [ $? -eq 0 ]; then
        notify "Connected" "$ssid"
    else
        # Don't leave a broken profile with a wrong password behind
        nmcli con delete id "$ssid" >/dev/null 2>&1
        notify -u critical "Could not connect to $ssid" "${out#Error: }"
    fi
}

main() {
    local rows=() actions=() rescan="${1:-no}"

    if [ -n "$wired" ]; then
        rows+=("$ICON_WIRED  Wired ($wired) connected"); actions+=(none)
    fi

    if [ -z "$wifi_dev" ]; then
        rows+=("$ICON_OFF  No Wi-Fi adapter"); actions+=(none)
    elif [ "$(nmcli radio wifi)" != "enabled" ]; then
        rows+=("$ICON_OFF  Wi-Fi is off: turn on"); actions+=(radio-on)
    else
        rows+=("$ICON_OFF  Turn Wi-Fi off"); actions+=(radio-off)

        # IN-USE:SIGNAL:SECURITY:SSID, strongest first, one row per SSID
        local line inuse signal security ssid seen="" icon
        while IFS= read -r line; do
            inuse=${line%%:*};   line=${line#*:}
            signal=${line%%:*};  line=${line#*:}
            security=${line%%:*}; ssid=${line#*:}
            ssid=${ssid//\\:/:}
            [ -z "$ssid" ] && continue
            grep -Fxq -- "$ssid" <<< "$seen" && continue
            seen+="$ssid"$'\n'
            icon=${SIGNAL[$(( signal >= 100 ? 4 : signal / 20 ))]}
            local mark="   " lock=""
            [ "$inuse" = "*" ] && mark="$ICON_CHECK "
            [ -n "$security" ] && [ "$security" != "--" ] && lock="  $ICON_LOCK"
            rows+=("$icon  $mark$ssid$lock"); actions+=("net:$inuse:$security:$ssid")
        done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan "$rescan" 2>/dev/null \
                 | sort -t: -k2,2nr)

        rows+=("$ICON_SCAN  Rescan"); actions+=(rescan)
        rows+=("$ICON_HIDDEN  Hidden network…"); actions+=(hidden)
    fi

    rows+=("$ICON_SETTINGS  Advanced settings (IP, DNS, VPN)…"); actions+=(editor)
    rows+=("$ICON_TUI  Open nmtui"); actions+=(nmtui)

    local n=${#rows[@]} idx
    idx=$(printf '%s\n' "${rows[@]}" | rofi_menu "Network" $(( n > 12 ? 12 : n ))) || exit 0
    [ -z "$idx" ] && exit 0

    local action=${actions[$idx]}
    case "$action" in
        radio-on)  nmcli radio wifi on;  sleep 2; main yes ;;
        radio-off) nmcli radio wifi off; notify "Wi-Fi off" ;;
        rescan)    main yes ;;
        hidden)
            local ssid pass
            ssid=$(ask "Network name (SSID)") || exit 0
            [ -z "$ssid" ] && exit 0
            pass=$(ask "Password (empty = open)" password) || exit 0
            if nmcli dev wifi connect "$ssid" ${pass:+password "$pass"} hidden yes ${wifi_dev:+ifname "$wifi_dev"} >/dev/null 2>&1; then
                notify "Connected" "$ssid"
            else
                nmcli con delete id "$ssid" >/dev/null 2>&1
                notify -u critical "Could not connect to $ssid"
            fi ;;
        editor)    setsid nm-connection-editor >/dev/null 2>&1 & ;;
        nmtui)     setsid kitty -e nmtui >/dev/null 2>&1 & ;;
        net:*)
            local rest=${action#net:} inuse security ssid
            inuse=${rest%%:*}; rest=${rest#*:}
            security=${rest%%:*}; ssid=${rest#*:}
            if [ "$inuse" = "*" ]; then
                local choice
                choice=$(printf '%s\n' "$ICON_DISC  Disconnect from $ssid" "$ICON_DISC  Forget $ssid" \
                    | rofi_menu "$ssid" 2) || exit 0
                case "$choice" in
                    0) nmcli dev disconnect "$wifi_dev" >/dev/null && notify "Disconnected" "$ssid" ;;
                    1) nmcli con delete id "$ssid" >/dev/null && notify "Forgot" "$ssid" ;;
                esac
            else
                connect "$ssid" "$security"
            fi ;;
    esac
}

main
