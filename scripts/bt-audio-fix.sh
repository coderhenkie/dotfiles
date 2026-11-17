#!/usr/bin/env bash
# ==========================================
# Bluetooth Audio Fix (A2DP)
# ==========================================
# Puts connected Bluetooth headphones back on the A2DP (high quality) profile when they are
# stuck on HSP/HFP (mono, phone-call quality). When no A2DP profile is offered at all (the
# A2DP link did not come up on connect), the device is disconnected and reconnected first.
# Afterwards the headphones become the default output. Result is shown as a notification.
# Bound to $mod+Shift+a in i3/hotkeys.default; also in Rofi's app launcher (scripts/desktop-entries.sh).
#
# Usage: bt-audio-fix.sh [-h|--help]

# No set -e: pactl/bluetoothctl return non-zero for devices that are mid-(re)connect.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need pactl bluetoothctl jq
single_instance bt-audio-fix

TITLE="Bluetooth audio"

# Prints the card's active profile, or nothing when the card does not exist (yet).
active_profile() {
    pactl --format=json list cards 2>/dev/null \
        | jq -r --arg c "$1" '.[] | select(.name == $c) | .active_profile'
}

# Prints the best available A2DP profile (highest priority), or nothing.
best_a2dp() {
    pactl --format=json list cards 2>/dev/null \
        | jq -r --arg c "$1" '.[] | select(.name == $c) | .profiles | to_entries
            | map(select((.key | startswith("a2dp")) and .value.available != false))
            | sort_by(-.value.priority) | .[0].key // empty'
}

# Sets the card to A2DP and makes its sink the default output.
use_a2dp() {
    local card="$1" profile="$2" sink
    pactl set-card-profile "$card" "$profile" || return 1
    sink=$(pactl --format=json list sinks short 2>/dev/null \
        | jq -r --arg m "bluez_output.${card#bluez_card.}" '.[] | select(.name | startswith($m)) | .name' \
        | head -n 1)
    [ -n "$sink" ] && pactl set-default-sink "$sink"
    return 0
}

mapfile -t cards < <(pactl --format=json list cards 2>/dev/null \
    | jq -r '.[] | select(.name | startswith("bluez_card.")) | .name')

if [ "${#cards[@]}" -eq 0 ]; then
    notify -u low "$TITLE" "No Bluetooth audio device connected."
    exit 1
fi

status=0
for card in "${cards[@]}"; do
    mac="${card#bluez_card.}"; mac="${mac//_/:}"
    name=$(bluetoothctl info "$mac" 2>/dev/null | sed -n 's/^\s*Alias: //p')
    name="${name:-$mac}"

    current=$(active_profile "$card")
    if [[ "$current" == a2dp* ]]; then
        use_a2dp "$card" "$current"
        notify -u low "$TITLE" "$name is already on A2DP ($current)."
        continue
    fi

    profile=$(best_a2dp "$card")
    if [ -z "$profile" ]; then
        notify -u low "$TITLE" "$name: no A2DP offered, reconnecting…"
        bluetoothctl disconnect "$mac" >/dev/null 2>&1
        sleep 2
        bluetoothctl connect "$mac" >/dev/null 2>&1
        # The card reappears a moment after the connection; wait up to ~10 s for A2DP.
        for _ in $(seq 20); do
            profile=$(best_a2dp "$card")
            [ -n "$profile" ] && break
            sleep 0.5
        done
    fi

    if [ -n "$profile" ] && use_a2dp "$card" "$profile"; then
        notify "$TITLE" "$name switched to A2DP ($profile)."
    else
        notify -u critical "$TITLE" "$name: A2DP still unavailable. Try turning the headphones off and on."
        status=1
    fi
done
exit "$status"
