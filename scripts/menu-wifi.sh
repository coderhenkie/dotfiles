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
ICON_WARN=$'\U000F0026'     # nf-md-alert
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

nm_running=$(nmcli -t -f RUNNING general 2>/dev/null)
devs=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null)
wifi_dev=$(awk -F: '$2 == "wifi" { print $1; exit }' <<< "$devs")
wifi_state=$(awk -F: '$2 == "wifi" { print $3; exit }' <<< "$devs")
wired=$(awk -F: '$2 == "ethernet" && $3 == "connected" { print $1; exit }' <<< "$devs")

profile_uuid() { # $1 ssid -> UUID of a saved Wi-Fi profile for that network (matched on the SSID, not the
    # profile name: profiles made by nmtui, nm-connection-editor or setup.sh can be named differently)
    local uuid type
    while IFS=: read -r uuid type; do
        [ "$type" = 802-11-wireless ] || continue
        if [ "$(nmcli -e no -g 802-11-wireless.ssid con show uuid "$uuid" 2>/dev/null)" = "$1" ]; then
            printf '%s\n' "$uuid"
            return 0
        fi
    done < <(nmcli -t -f UUID,TYPE con show 2>/dev/null)
    return 1
}

connect_with_psk() { # $1 ssid, $2 pass, [$3 = hidden], [$4 = security from nmcli]
    # The password never goes on nmcli's command line (visible in ps / /proc/*/cmdline): it is
    # handed over through a file descriptor (`passwd-file`, see `man nmcli`, `connection up`).
    local ssid="$1" pass="$2" hidden="${3:-}" security="${4:-}" key_mgmt=wpa-psk uuid out
    if ! uuid=$(profile_uuid "$ssid"); then
        # WPA3-only networks need SAE; mixed WPA2/WPA3 and WPA2 use WPA-PSK
        [[ "$security" == *WPA3* && "$security" != *WPA2* && "$security" != *WPA1* ]] && key_mgmt=sae
        out=$(nmcli con add type wifi con-name "$ssid" ssid "$ssid" \
            ${hidden:+802-11-wireless.hidden yes} wifi-sec.key-mgmt "$key_mgmt" 2>&1) || { printf '%s\n' "$out"; return 1; }
        uuid=$(profile_uuid "$ssid") || { echo "Error: the new profile for $ssid was not saved."; return 1; }
    fi
    nmcli con up uuid "$uuid" ${wifi_dev:+ifname "$wifi_dev"} \
        passwd-file /dev/fd/3 3<<<"802-11-wireless-security.psk:$pass" 2>&1
}

forget_new_profile() { # $1 ssid, $2 had_profile: remove the profile a failed first attempt left behind
    local uuid
    [ "$2" = no ] && uuid=$(profile_uuid "$1") && { nmcli con delete uuid "$uuid" >/dev/null 2>&1 || true; }
}

connect() { # $1 ssid, $2 security
    local ssid="$1" security="$2" pass out rc had_profile=no uuid
    if uuid=$(profile_uuid "$ssid"); then
        had_profile=yes
        out=$(nmcli con up uuid "$uuid" 2>&1) && { notify_net "Connected" "$ssid"; return; }
        # Saved password may be outdated: ask again below
    fi
    if [[ "$security" == *802.1X* ]]; then
        # Enterprise Wi-Fi (eduroam, work) needs a username, EAP method and CA certificate: a password
        # alone always fails, so open the editor for a new profile instead
        if [ "$had_profile" = yes ]; then
            # The saved login failed: edit that profile instead of making a second one
            notify_net -u critical "Could not connect to $ssid" "${out#Error: } (check the login in the connection editor)"
            setsid nm-connection-editor --edit="$uuid" >/dev/null 2>&1 &
        else
            notify_net "$ssid needs a login (802.1X)" "Set it up in the connection editor: Wi-Fi, SSID $ssid, tab Wi-Fi Security."
            setsid nm-connection-editor --create --type=802-11-wireless >/dev/null 2>&1 &
        fi
        return
    elif [ -n "$security" ] && [ "$security" != "--" ]; then
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
        forget_new_profile "$ssid" "$had_profile"
        notify_net -u critical "Could not connect to $ssid" "${out#Error: }"
    fi
}

main() {
    # First open: rescan when the last scan is older than 30 s (after boot or resume the cached list is empty)
    local rows=() actions=() net_inuse=() net_sec=() net_ssid=() rescan="${1:-auto}"

    if [ -n "$wired" ]; then
        rows+=("$ICON_WIRED  Wired ($wired) connected"); actions+=(none)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    fi

    if [ "$nm_running" != running ]; then
        rows+=("$ICON_WARN  NetworkManager is not running (systemctl status NetworkManager)"); actions+=(none)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    elif [ -z "$wifi_dev" ]; then
        rows+=("$ICON_OFF  No Wi-Fi adapter"); actions+=(none)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    elif [ "$wifi_state" = unmanaged ]; then
        # Set up by the Debian installer in /etc/network/interfaces (ifupdown); setup.sh hands it over
        rows+=("$ICON_WARN  $wifi_dev is not managed by NetworkManager (see /etc/network/interfaces)"); actions+=(none)
        net_inuse+=(""); net_sec+=(""); net_ssid+=("")
    elif [ "$wifi_state" = unavailable ] && [ "$(nmcli radio wifi)" = enabled ]; then
        # Radio on but the card can't be used: usually wpa_supplicant (masked/stopped) or a hardware rfkill switch
        rows+=("$ICON_WARN  $wifi_dev unavailable (check wpa_supplicant / rfkill)"); actions+=(none)
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
        radio-on)
            nmcli radio wifi on
            # The card needs a moment before it can scan: wait (max ~8 s) until it leaves "unavailable"
            local i
            for i in 1 2 3 4 5 6 7 8; do
                [ "$(nmcli -t -f DEVICE,STATE dev 2>/dev/null | awk -F: -v d="$wifi_dev" '$1 == d { print $2 }')" != unavailable ] && break
                sleep 1
            done
            wifi_state=$(nmcli -t -f DEVICE,STATE dev 2>/dev/null | awk -F: -v d="$wifi_dev" '$1 == d { print $2 }')
            main yes ;;
        radio-off) nmcli radio wifi off; notify_net "Wi-Fi off" ;;
        rescan)    main yes ;;
        hidden)
            local ssid pass rc out had_profile=no
            ssid=$(ask "Network name (SSID)") || exit 0
            [ -z "$ssid" ] && exit 0
            profile_uuid "$ssid" >/dev/null && had_profile=yes
            pass=$(ask "Password (empty = open)" password) || exit 0
            if [ -n "$pass" ]; then
                out=$(connect_with_psk "$ssid" "$pass" hidden)
                rc=$?
            else
                out=$(nmcli dev wifi connect "$ssid" hidden yes ${wifi_dev:+ifname "$wifi_dev"} 2>&1)
                rc=$?
            fi
            if [ "$rc" -eq 0 ]; then
                notify_net "Connected" "$ssid"
            else
                forget_new_profile "$ssid" "$had_profile"
                notify_net -u critical "Could not connect to $ssid" "${out#Error: }"
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
                    1)  # The profile that is active on the card, whatever its name
                        local uuid out=""
                        uuid=$(nmcli -t -f UUID,DEVICE con show --active 2>/dev/null \
                            | awk -F: -v d="$wifi_dev" '$2 == d { print $1; exit }')
                        [ -n "$uuid" ] || uuid=$(profile_uuid "$ssid")
                        if [ -n "$uuid" ] && out=$(nmcli con delete uuid "$uuid" 2>&1); then
                            notify_net "Forgot" "$ssid"
                        else
                            notify_net -u critical "Could not forget $ssid" "${out#Error: }"
                        fi ;;
                esac
            else
                connect "$ssid" "$security"
            fi ;;
    esac
}

main
