#!/usr/bin/env bash
# ==========================================
# Monitor Layout (multi-screen setup)
# ==========================================
# Detects the connected screens and, with 2 or more, asks which one is left / middle / right
# by number. The screens are first put side by side and every screen shows its number in big
# digits, so you can see which number belongs to which physical screen.
# The chosen layout is applied (each screen at its preferred resolution and highest refresh
# rate) and saved as autorandr profile `main`, so it comes back at every login and replug.
#
#   monitor-layout.sh          ask in the terminal (also called by setup.sh)
#   monitor-layout.sh --list   only show the detected screens
#
# Primary screen (tray, new workspaces): left with 2 screens, middle with 3, otherwise the first.

# No set -e: interactive terminal prompts and optional autorandr/yad calls handle their own exits.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/monitor-splash.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/monitor-splash.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need xrandr

PROFILE="main"

if [ -z "${DISPLAY:-}" ] || ! xrandr --query >/dev/null 2>&1; then
    die "No X display: run $DOTFILES_DIR/scripts/monitor-layout.sh from inside the desktop session."
fi

# Connected outputs, in xrandr order
mapfile -t OUTPUTS < <(xrandr --query | awk '$2 == "connected" {print $1}')
N=${#OUTPUTS[@]}

# describe <output>: "2560x1440 @ 165Hz, 597mm x 336mm"
describe() {
    xrandr --query | awk -v out="$1" '
        $1 == out { found = 1; size = ($0 ~ /mm x/) ? $(NF-2) " x " $NF : ""; next }
        found && /^[A-Za-z]/ { exit }
        found && pref == "" && /\+/ {
            res = $1; best = 0
            for (i = 2; i <= NF; i++) { r = $i; gsub(/[*+]/, "", r); if (r + 0 > best) best = r + 0 }
            pref = res " @ " int(best + 0.5) "Hz"
        }
        END { printf "%s%s", pref, (size != "" ? ", " size : "") }'
}

# best_rate <output>: highest refresh rate of the preferred (+) mode
best_rate() {
    xrandr --query | awk -v out="$1" '
        $1 == out { found = 1; next }
        found && /^[A-Za-z]/ { exit }
        found && /\+/ { best = 0
            for (i = 2; i <= NF; i++) { r = $i; gsub(/[*+]/, "", r); if (r + 0 > best) { best = r + 0; raw = r } }
            print raw; exit }'
}

# apply_order <output>...: place the outputs left to right, preferred mode, highest refresh rate
apply_order() {
    local -a args=()
    local primary i prev="" rate
    case $# in
        2) primary=$1 ;;
        3) primary=$2 ;;
        *) primary=$1 ;;
    esac
    for i in "$@"; do
        args+=(--output "$i" --auto)
        rate=$(best_rate "$i")
        [ -n "$rate" ] && args+=(--rate "$rate")
        if [ -z "$prev" ]; then args+=(--pos 0x0); else args+=(--right-of "$prev"); fi
        [ "$i" = "$primary" ] && args+=(--primary)
        prev=$i
    done
    # Switch off outputs that are still enabled but no longer connected
    for i in $(xrandr --query | awk '$2 == "disconnected" && $3 ~ /^[0-9]+x[0-9]+/ {print $1}'); do
        args+=(--output "$i" --off)
    done
    xrandr "${args[@]}"
}

log "Detected $N screen(s):"
for i in "${!OUTPUTS[@]}"; do
    printf '    %d) %-10s %s\n' "$((i + 1))" "${OUTPUTS[$i]}" "$(describe "${OUTPUTS[$i]}")"
done
[ "${1:-}" = "--list" ] && exit 0

if [ "$N" -eq 0 ]; then
    die "No connected screens found."
fi

if [ "$N" -eq 1 ]; then
    apply_order "${OUTPUTS[0]}"
    ok "One screen: nothing to arrange."
    exit 0
fi

if ! ( : </dev/tty ) 2>/dev/null; then
    warn "No terminal to ask on: run $DOTFILES_DIR/scripts/monitor-layout.sh later to arrange the screens."
    exit 0
fi

# Put the screens side by side (they may be mirrored now) and show each screen's number on it
apply_order "${OUTPUTS[@]}"
sleep 1
if have yad; then
    monitor_splash_show "${OUTPUTS[@]}"
    echo "    (Every screen now shows its number.)"
fi
trap monitor_splash_hide EXIT

# Position names, left to right
case $N in
    2) SLOTS=("LEFT" "RIGHT") ;;
    3) SLOTS=("LEFT" "MIDDLE" "RIGHT") ;;
    *) SLOTS=(); for ((s = 1; s <= N; s++)); do SLOTS+=("position $s (from the left)"); done ;;
esac

ORDER=()
REMAINING=("${!OUTPUTS[@]}")   # indices still to place
for ((s = 0; s < N - 1; s++)); do
    while true; do
        nums=""
        for r in "${REMAINING[@]}"; do nums+="$((r + 1))/"; done
        printf 'Which screen should be %s? [%s]: ' "${SLOTS[$s]}" "${nums%/}" >/dev/tty
        IFS= read -r answer </dev/tty || exit 1
        idx=""
        for k in "${!REMAINING[@]}"; do
            [ "$answer" = "$((REMAINING[k] + 1))" ] && { idx=${REMAINING[k]}; unset 'REMAINING[k]'; break; }
        done
        [ -n "$idx" ] && break
        echo "    Please enter one of: ${nums%/}" >/dev/tty
    done
    REMAINING=("${REMAINING[@]}")
    ORDER+=("${OUTPUTS[$idx]}")
done
# The last screen gets the last position
ORDER+=("${OUTPUTS[${REMAINING[0]}]}")
echo "    ${SLOTS[$((N - 1))]}: screen $((REMAINING[0] + 1)) (${OUTPUTS[${REMAINING[0]}]})"

monitor_splash_hide

apply_order "${ORDER[@]}"
ok "Layout (left -> right): ${ORDER[*]}"

if have autorandr; then
    autorandr --save "$PROFILE" --force >/dev/null && \
        ok "Saved as autorandr profile '$PROFILE' (restored at login and when the screens are replugged)."
    # Same effect as an autorandr switch: re-launch Polybar and the wallpaper for the new layout
    [ -x "$HOME/.config/autorandr/postswitch" ] && AUTORANDR_CURRENT_PROFILE="$PROFILE" "$HOME/.config/autorandr/postswitch"
fi
exit 0
