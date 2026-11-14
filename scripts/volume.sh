#!/usr/bin/env bash
# Volume up/down in 5% steps that always land on a multiple of 5 (42% -> 45% / 40%).
# Used by the i3 volume keys and Polybar scroll.  Usage: volume.sh up|down
# Max 150% (same ceiling as Polybar's use-ui-max).

step=5
max=150

cur=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oE '[0-9]+%' | head -n 1 | tr -d %)
[ -n "$cur" ] || exit 1

case "$1" in
    up)   new=$(( (cur / step + 1) * step )) ;;
    down) new=$(( (cur + step - 1) / step * step - step )) ;;
    *)    echo "Usage: $0 up|down" >&2; exit 2 ;;
esac

(( new > max )) && new=$max
(( new < 0 )) && new=0
pactl set-sink-volume @DEFAULT_SINK@ "${new}%"
