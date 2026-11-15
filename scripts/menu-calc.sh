#!/usr/bin/env bash
# ==========================================
# Rofi Calculator (qalc)
# ==========================================
# Type an expression and press Enter to see the result; keep typing to continue
# calculating. Select the result row to copy it to the clipboard. Esc closes.
# qalc understands units, currencies and percentages too: "85 * 20%", "1.5 h to min",
# "100 EUR to USD", "sqrt(2)".
# Bound to $mod+equal.
#
# Usage: menu-calc.sh [-h|--help]

# No set -e: rofi exits non-zero when the user presses Esc to close the calculator.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need qalc rofi xclip

result=""
msg="Type an expression, e.g. <b>12*7</b>, <b>85 * 20%</b>, <b>1.5 h to min</b>, <b>100 EUR to USD</b>"

while true; do
    input=$(printf '%s' "$result" | rofi -dmenu -p "Calc" -mesg "$msg" \
        -theme-str 'window { width: 34%; } listview { lines: 1; }') || exit 0
    [ -z "$input" ] && exit 0

    # Selecting the result row copies it
    if [ -n "$result" ] && [ "$input" = "$result" ]; then
        printf '%s' "$result" | xclip -selection clipboard
        notify -a "Calculator" -u low "Copied" "$result"
        exit 0
    fi

    result=$(qalc -t -- "$input" 2>&1 | tail -n 1)
    safe_in=$(pango_escape "$input")
    safe_out=$(pango_escape "$result")
    msg="$safe_in = <b>$safe_out</b>   (select the result to copy it)"
done
