#!/usr/bin/env bash
# ==========================================
# Volume Control (PulseAudio / PipeWire)
# ==========================================
# Volume up/down in 5% steps that always land on a multiple of 5 (42% -> 45% / 40%).
# Used by the i3 volume keys and Polybar scroll.
# Max 150% (same ceiling as Polybar's use-ui-max).
#
# Usage: volume.sh up|down [-h|--help]

# No set -e: arithmetic expressions (( ... )) evaluate to exit code 1 when false.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need pactl

step=5
max=150

cur=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -n 1 | tr -d % || true)
[ -n "$cur" ] || exit 1

case "${1:-}" in
    up)   new=$(( (cur / step + 1) * step )) ;;
    down) new=$(( (cur + step - 1) / step * step - step )) ;;
    *)    help_from_header >&2; exit 2 ;;
esac

(( new > max )) && new=$max
(( new < 0 )) && new=0
pactl set-sink-volume @DEFAULT_SINK@ "${new}%"
