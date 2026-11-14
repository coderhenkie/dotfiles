#!/usr/bin/env bash
# Polybar battery status: "<capacity>% (<status>)".
# Prints nothing on machines without a battery (desktops, VMs), so the module hides itself.

bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)
[ -n "$bat" ] && [ -f "$bat/capacity" ] || exit 0

echo "$(cat "$bat/capacity")% ($(cat "$bat/status" 2>/dev/null || echo Unknown))"
