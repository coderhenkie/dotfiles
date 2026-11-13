#!/usr/bin/env bash
# ==========================================
# Low Battery Notifications (dunst)
# ==========================================
# Started once per login from i3/config. Exits immediately on machines without a
# battery (desktops, VMs). While discharging it warns once at 20% and again
# (critical, stays until clicked) at 10% and 5%. Plugging in resets the warnings.

BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)
[ -z "$BAT" ] && exit 0

LOCK="${XDG_RUNTIME_DIR:-/tmp}/battery-notify.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

warned=100
while true; do
    capacity=$(cat "$BAT/capacity" 2>/dev/null || echo 100)
    status=$(cat "$BAT/status" 2>/dev/null || echo Unknown)

    if [ "$status" != "Discharging" ]; then
        warned=100
    else
        for level in 5 10 20; do
            if [ "$capacity" -le "$level" ] && [ "$warned" -gt "$level" ]; then
                warned=$level
                if [ "$level" -le 10 ]; then
                    notify-send -a "Battery" -u critical "Battery at ${capacity}%" "Plug in the charger now"
                else
                    notify-send -a "Battery" "Battery low (${capacity}%)" "Consider plugging in the charger"
                fi
                break
            fi
        done
    fi
    sleep 60
done
