#!/usr/bin/env bash
# ==========================================
# Low Battery Notifications (dunst)
# ==========================================
# Started once per login from i3/config. Exits immediately on machines without a
# battery (desktops, VMs). While discharging it warns once at 20% and again
# (critical, stays until clicked) at 10% and 5%. Plugging in resets the warnings.
#
# Usage: battery-notify.sh [-h|--help]

# No set -e: background daemon loop where sysfs reads may transiently fail.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

BAT=""
for d in /sys/class/power_supply/BAT*; do
    [ -f "$d/capacity" ] && { BAT="$d"; break; }
done
[ -n "$BAT" ] || exit 0

i3_env
single_instance battery-notify

warned=100
while session_alive; do
    capacity=$(cat "$BAT/capacity" 2>/dev/null || echo 100)
    status=$(cat "$BAT/status" 2>/dev/null || echo Unknown)

    if [ "$status" != "Discharging" ]; then
        warned=100
    else
        for level in 5 10 20; do
            if [ "$capacity" -le "$level" ] && [ "$warned" -gt "$level" ]; then
                warned=$level
                if [ "$level" -le 10 ]; then
                    notify -a "Battery" -u critical "Battery at ${capacity}%" "Plug in the charger now"
                else
                    notify -a "Battery" "Battery low (${capacity}%)" "Consider plugging in the charger"
                fi
                break
            fi
        done
    fi
    sleep 60
done
