#!/usr/bin/env bash
# ==========================================
# Polybar Battery Status Module
# ==========================================
# Prints "<capacity>% (<status>)".
# Prints nothing on machines without a battery (desktops, VMs), so the module hides itself.
#
# Usage: polybar-battery.sh [-h|--help]

# No set -e: sysfs battery files may be absent on desktops/VMs.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

bat=""
for d in /sys/class/power_supply/BAT*; do
    [ -f "$d/capacity" ] && { bat="$d"; break; }
done
[ -n "$bat" ] || exit 0

echo "$(cat "$bat/capacity" 2>/dev/null || echo 0)% ($(cat "$bat/status" 2>/dev/null || echo Unknown))"
