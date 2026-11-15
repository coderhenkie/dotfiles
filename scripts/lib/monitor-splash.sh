#!/usr/bin/env bash
# ==========================================
# Monitor geometry & on-screen numbering splash (sourced by menu-monitors.sh and monitor-layout.sh)
# ==========================================
#   monitor_geometry <output>       prints "w h x y rotation" for an active xrandr output (empty when off)
#   monitor_splash_show <output>... shows big screen numbers (1..N) centered on each active output via yad
#   monitor_splash_hide             closes any running monitor splash windows

[ -n "${_DOTFILES_MONITOR_SPLASH_LOADED:-}" ] && return 0
_DOTFILES_MONITOR_SPLASH_LOADED=1

MONITOR_SPLASH_PIDS=()

monitor_geometry() {
    xrandr --query | awk -v out="$1" '$1 == out {
        rot = "normal"
        for (f = 3; f <= NF; f++) {
            if ($f ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
                geo = $f
                if ($(f+1) ~ /^(left|right|inverted)$/) rot = $(f+1)
            }
        }
        if (geo != "") { gsub(/[x+]/, " ", geo); print geo, rot }
        exit
    }'
}

monitor_splash_hide() {
    if [ "${#MONITOR_SPLASH_PIDS[@]}" -gt 0 ]; then
        kill "${MONITOR_SPLASH_PIDS[@]}" 2>/dev/null || true
        MONITOR_SPLASH_PIDS=()
    fi
}

monitor_splash_show() {
    monitor_splash_hide
    command -v yad >/dev/null 2>&1 || return 0
    local -a outs=("$@")
    local i w h x y _
    for i in "${!outs[@]}"; do
        read -r w h x y _ <<< "$(monitor_geometry "${outs[$i]}")"
        [ -z "${w:-}" ] && continue
        yad --splash --undecorated --no-buttons --skip-taskbar --on-top --no-focus \
            --title="Screen $((i + 1))" --class="MonitorId" \
            --width=360 --height=300 --posx=$((x + (w - 360) / 2)) --posy=$((y + (h - 300) / 2)) \
            --text="<span font='160' weight='bold'>$((i + 1))</span>\n<span font='18'>${outs[$i]}</span>" \
            --text-align=center >/dev/null 2>&1 &
        MONITOR_SPLASH_PIDS+=($!)
    done
}
