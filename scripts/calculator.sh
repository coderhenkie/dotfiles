#!/usr/bin/env bash
# ==========================================
# Rofi Calculator (qalc)
# ==========================================
# Type an expression and press Enter to see the result; keep typing to continue
# calculating. Select the result row to copy it to the clipboard. Esc closes.
# qalc understands units, currencies and percentages too: "85 * 20%", "1.5 h to min",
# "100 EUR to USD", "sqrt(2)".
# Bound to $mod+equal.

result=""
msg="Type an expression, e.g. <b>12*7</b>, <b>85 * 20%</b>, <b>1.5 h to min</b>, <b>100 EUR to USD</b>"

while true; do
    input=$(printf '%s' "$result" | rofi -dmenu -p "Calc" -mesg "$msg" \
        -theme-str 'window { width: 34%; } listview { lines: 1; }')
    [ -z "$input" ] && exit 0

    # Selecting the result row copies it
    if [ -n "$result" ] && [ "$input" = "$result" ]; then
        printf '%s' "$result" | xclip -selection clipboard
        notify-send -a "Calculator" -u low "Copied" "$result" 2>/dev/null
        exit 0
    fi

    result=$(qalc -t -- "$input" 2>&1 | tail -n 1)
    safe_in=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<< "$input")
    safe_out=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<< "$result")
    msg="$safe_in = <b>$safe_out</b>   (select the result to copy it)"
done
