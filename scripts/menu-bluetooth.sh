#!/usr/bin/env bash
# ==========================================
# Bluetooth Menu (Rofi + bluetoothctl)
# ==========================================
# Opened by left-clicking the Bluetooth icon in the bottom Polybar (right-click toggles power).
# Lists paired devices (connected ones checked, with battery level when the device reports
# it); pick one to connect / disconnect / forget it. "Pair new device…"
# scans for ~10 s and pairs + trusts + connects the chosen device (PIN prompts, if any,
# come from blueman-applet, which stays running as the pairing agent). Also: power on/off
# and blueman-manager for advanced settings. Themed via ~/.cache/theme/rofi.rasi like every
# other menu-*.sh.

ICON_ON=$'\U000F00AF'       # nf-md-bluetooth
ICON_OFF=$'\U000F00B2'      # nf-md-bluetooth_off
ICON_CHECK=$'\U000F012C'    # nf-md-check
ICON_SCAN=$'\U000F00B1'     # nf-md-bluetooth_settings (searching)
ICON_DISC=$'\U000F0156'     # nf-md-close
ICON_SETTINGS=$'\U000F0493' # nf-md-cog
ICON_DEVICE=$'\U000F00B0'   # nf-md-bluetooth_connect (generic)
ICON_HEADSET=$'\U000F02CB'  # nf-md-headphones
ICON_SPEAKER=$'\U000F04C3'  # nf-md-speaker
ICON_MOUSE=$'\U000F037D'    # nf-md-mouse
ICON_KEYBOARD=$'\U000F030C' # nf-md-keyboard
ICON_PHONE=$'\U000F011C'    # nf-md-cellphone
ICON_GAMEPAD=$'\U000F0296'  # nf-md-gamepad_variant
ICON_COMPUTER=$'\U000F0379' # nf-md-monitor

export DISPLAY="${DISPLAY:-:0}"

notify() { notify-send -a "Bluetooth" "$@"; }

rofi_menu() { # $1 prompt, $2 lines; options on stdin; prints the chosen index
    rofi -dmenu -i -format i -p "$1" -theme-str "window { width: 30%; } listview { lines: $2; }"
}

[ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] || { notify "No Bluetooth adapter found"; exit 0; }

powered() { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; }

power_on() {
    rfkill unblock bluetooth 2>/dev/null
    bluetoothctl power on >/dev/null
    sleep 1
}

device_icon() { # $1 = bluetoothctl "Icon:" value
    case "$1" in
        audio-headset|audio-headphones) echo "$ICON_HEADSET" ;;
        audio-card|audio-speakers)      echo "$ICON_SPEAKER" ;;
        input-mouse|input-tablet)       echo "$ICON_MOUSE" ;;
        input-keyboard)                 echo "$ICON_KEYBOARD" ;;
        input-gaming)                   echo "$ICON_GAMEPAD" ;;
        phone)                          echo "$ICON_PHONE" ;;
        computer)                       echo "$ICON_COMPUTER" ;;
        *)                              echo "$ICON_DEVICE" ;;
    esac
}

# Prints "MAC<TAB>Name" per line for: bluetoothctl devices [Paired|Connected|...]
list_devices() { bluetoothctl devices "$@" 2>/dev/null | awk '$1 == "Device" { mac=$2; $1=$2=""; sub(/^ +/, ""); print mac "\t" $0 }'; }

connect() { # $1 mac, $2 name
    if bluetoothctl connect "$1" 2>&1 | grep -q 'Connection successful'; then
        notify "Connected" "$2"
    else
        notify -u critical "Could not connect to $2" "Is it switched on and in range?"
    fi
}

pair_new() {
    local paired rows=() macs=() mac name icon
    notify -t 10000 "Scanning for devices…" "Put your device in pairing mode"
    bluetoothctl --timeout 10 scan on >/dev/null 2>&1
    paired=$(list_devices Paired | cut -f1)
    while IFS=$'\t' read -r mac name; do
        grep -Fxq -- "$mac" <<< "$paired" && continue
        # Skip nameless devices (bluez shows them as their MAC with dashes)
        [ "$name" = "${mac//:/-}" ] && continue
        icon=$(device_icon "$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/Icon:/ { print $2; exit }')")
        rows+=("$icon  $name"); macs+=("$mac")
    done < <(list_devices)

    if [ ${#rows[@]} -eq 0 ]; then
        notify "No new devices found" "Make sure the device is in pairing mode, then try again"
        return
    fi
    rows+=("$ICON_SCAN  Scan again"); macs+=(rescan)

    local n=${#rows[@]} idx
    idx=$(printf '%s\n' "${rows[@]}" | rofi_menu "Pair" $(( n > 12 ? 12 : n ))) || return
    [ -z "$idx" ] && return
    mac=${macs[$idx]}
    [ "$mac" = rescan ] && { pair_new; return; }
    name=${rows[$idx]#*  }

    notify "Pairing…" "$name"
    if bluetoothctl pair "$mac" 2>&1 | grep -qE 'Pairing successful|AlreadyExists'; then
        bluetoothctl trust "$mac" >/dev/null
        connect "$mac" "$name"
    else
        notify -u critical "Pairing with $name failed" "Put it in pairing mode and try again"
    fi
}

main() {
    local rows=() actions=()

    if ! powered; then
        rows+=("$ICON_OFF  Bluetooth is off: turn on"); actions+=(power-on)
    else
        rows+=("$ICON_OFF  Turn Bluetooth off"); actions+=(power-off)

        local mac name info icon mark battery connected_rows=() connected_actions=() other_rows=() other_actions=()
        while IFS=$'\t' read -r mac name; do
            info=$(bluetoothctl info "$mac" 2>/dev/null)
            icon=$(device_icon "$(awk -F': ' '/Icon:/ { print $2; exit }' <<< "$info")")
            battery=$(sed -n 's/.*Battery Percentage: 0x[0-9a-fA-F]* (\([0-9]*\)).*/\1/p' <<< "$info" | head -n 1)
            if grep -q 'Connected: yes' <<< "$info"; then
                connected_rows+=("$icon  $ICON_CHECK $name${battery:+  ($battery%)}"); connected_actions+=("on:$mac:$name")
            else
                other_rows+=("$icon     $name"); other_actions+=("off:$mac:$name")
            fi
        done < <(list_devices Paired)
        rows+=("${connected_rows[@]}" "${other_rows[@]}")
        actions+=("${connected_actions[@]}" "${other_actions[@]}")

        rows+=("$ICON_SCAN  Pair new device…"); actions+=(pair)
    fi
    rows+=("$ICON_SETTINGS  Advanced settings (blueman)…"); actions+=(manager)

    local n=${#rows[@]} idx
    idx=$(printf '%s\n' "${rows[@]}" | rofi_menu "Bluetooth" $(( n > 12 ? 12 : n ))) || exit 0
    [ -z "$idx" ] && exit 0

    local action=${actions[$idx]}
    case "$action" in
        power-on)  power_on; main ;;
        power-off) bluetoothctl power off >/dev/null; notify "Bluetooth off" ;;
        pair)      pair_new ;;
        manager)   setsid blueman-manager >/dev/null 2>&1 & ;;
        on:*|off:*)
            local state=${action%%:*} rest=${action#*:}
            mac=${rest:0:17}; name=${rest:18}
            local first choice
            if [ "$state" = off ]; then first="$ICON_DEVICE  Connect $name"; else first="$ICON_DISC  Disconnect $name"; fi
            choice=$(printf '%s\n' "$first" "$ICON_DISC  Forget $name" | rofi_menu "$name" 2) || exit 0
            case "$choice:$state" in
                0:off) connect "$mac" "$name" ;;
                0:on)  bluetoothctl disconnect "$mac" >/dev/null && notify "Disconnected" "$name" ;;
                1:*)   bluetoothctl remove "$mac" >/dev/null && notify "Forgot" "$name" ;;
            esac ;;
    esac
}

main
