#!/usr/bin/env bash
# ==========================================
# Monitor Menu (Rofi)
# ==========================================
# Screen setup, bound to $mod+p. While a menu is open every screen shows its number in big digits.
#   Extend   : the saved layout (autorandr profile `main`); asks where the screens go first if
#              there is no saved layout for these screens yet
#   Mirror   : every screen shows the same picture (autorandr's built-in `common` profile)
#   Arrange  : put a screen left of / right of / above / below another one
#   Rotate   : landscape, portrait (counter-clockwise / clockwise) or upside down, per screen
# Arrange and Rotate apply immediately, re-line the screens up so nothing overlaps (top-aligned
# side by side, left-aligned stacked) and save the result as autorandr profile `main`, so it comes
# back at every login and replug. Workspaces and Polybar follow via the autorandr postswitch hook
# (scripts/workspaces.sh: 2 screens = workspaces 1-4 on the left/top one, 5-10 on the other).
# scripts/monitor-layout.sh is the terminal version (used by setup.sh).
#
# Usage: menu-monitors.sh [-h|--help]

# No set -e: rofi returns non-zero on Esc/cancel and autorandr may return non-zero when no profile matches.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/monitor-splash.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/monitor-splash.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need xrandr rofi autorandr

ICON_EXTEND=$'\U000F0380'    # nf-md-monitor_multiple
ICON_MIRROR=$'\U000F0379'    # nf-md-monitor
ICON_ARRANGE=$'\U000F04E1'   # nf-md-swap_horizontal
ICON_ROTATE=$'\U000F0465'    # nf-md-rotate_right
ICON_LEFT=$'\U000F004D'      # nf-md-arrow_left
ICON_RIGHT=$'\U000F0054'     # nf-md-arrow_right
ICON_UP=$'\U000F005D'        # nf-md-arrow_up
ICON_DOWN=$'\U000F0045'      # nf-md-arrow_down
ICON_LANDSCAPE=$'\U000F0379' # nf-md-monitor
ICON_CCW=$'\U000F0467'       # nf-md-rotate_left
ICON_FLIP=$'\U000F0A49'      # nf-md-rotate_3d_variant

PROFILE="main"

notify_disp() { notify -a "Display" -u low "Display" "$1"; }

menu() { # $1 prompt, $2 message, $3 lines; options on stdin; prints the chosen index
    rofi -dmenu -i -format i -p "$1" ${2:+-mesg "$2"} -theme-str "window { width: 30%; } listview { lines: $3; }"
}

mapfile -t OUTPUTS < <(xrandr --query | awk '$2 == "connected" {print $1}')
N=${#OUTPUTS[@]}
[ "$N" -eq 0 ] && { notify_disp "No screens detected."; exit 0; }

rotation_label() {
    case "$1" in
        left)     echo "portrait, counter-clockwise" ;;
        right)    echo "portrait, clockwise" ;;
        inverted) echo "upside down" ;;
        *)        echo "landscape" ;;
    esac
}

is_mirrored() { # every active screen at the same position
    [ "$N" -ge 2 ] && [ "$(for o in "${OUTPUTS[@]}"; do monitor_geometry "$o" | awk '{print $3, $4}'; done | sort -u | wc -l)" -le 1 ]
}

show_numbers() { monitor_splash_show "${OUTPUTS[@]}"; }
hide_numbers() { monitor_splash_hide; }
trap hide_numbers EXIT

screen_rows() { # "1  DP-2  2560x1440, landscape (primary)" per screen
    local i w h _ rot
    for i in "${!OUTPUTS[@]}"; do
        read -r w h _ _ rot <<< "$(monitor_geometry "${OUTPUTS[$i]}")"
        if [ -z "${w:-}" ]; then
            printf '%s  %s  (off)\n' "$((i + 1))" "${OUTPUTS[$i]}"
        else
            printf '%s  %s  %sx%s, %s\n' "$((i + 1))" "${OUTPUTS[$i]}" "$w" "$h" "$(rotation_label "$rot")"
        fi
    done
}

pick_screen() { # $1 prompt, [$2 index to leave out] -> output name
    local rows=() map=() i line
    i=0
    while IFS= read -r line; do
        [ "${2:-}" != "$i" ] && { rows+=("$ICON_LANDSCAPE  Screen $line"); map+=("$i"); }
        i=$((i + 1))
    done < <(screen_rows)
    [ ${#rows[@]} -eq 1 ] && { echo "${OUTPUTS[${map[0]}]}"; return; }
    local idx
    idx=$(printf '%s\n' "${rows[@]}" | menu "$1" "" "${#rows[@]}") || return 1
    [ -n "$idx" ] && echo "${OUTPUTS[${map[$idx]}]}"
}

# Re-line the screens up after a change: chain them in position order, each one next to the
# previous in the direction it already was (right/left of, above/below), so rotated screens never
# overlap or leave gaps. Takes extra xrandr args (e.g. a --rotate) to apply in the same call.
relayout() {
    local -a active=() args=() sorted
    local o g
    for o in "${OUTPUTS[@]}"; do g=$(monitor_geometry "$o"); [ -n "$g" ] && active+=("$o $g"); done
    if [ ${#active[@]} -ge 2 ] && ! is_mirrored; then
        mapfile -t sorted < <(printf '%s\n' "${active[@]}" \
            | awk '{ printf "%d %d %s %d %d %d %d\n", $4 + $2 / 2, $5 + $3 / 2, $1, $2, $3, $4, $5 }' | sort -n -k1,1 -k2,2)
        local prev="" pcx pcy cx cy name dx dy
        for o in "${sorted[@]}"; do
            read -r cx cy name _ <<< "$o"
            if [ -z "$prev" ]; then
                args+=(--output "$name" --pos 0x0)
            else
                dx=$((cx - pcx)); dy=$((cy - pcy))
                if [ "${dx#-}" -ge "${dy#-}" ]; then
                    if [ "$dx" -ge 0 ]; then
                        args+=(--output "$name" --right-of "$prev")
                    else
                        args+=(--output "$name" --left-of "$prev")
                    fi
                else
                    if [ "$dy" -ge 0 ]; then
                        args+=(--output "$name" --below "$prev")
                    else
                        args+=(--output "$name" --above "$prev")
                    fi
                fi
            fi
            prev=$name; pcx=$cx; pcy=$cy
        done
    fi
    [ ${#args[@]} -gt 0 ] && xrandr "${args[@]}"
    return 0
}

save_layout() {
    autorandr --save "$PROFILE" --force >/dev/null 2>&1 || true
    # Same as an autorandr switch: Polybar, workspaces and wallpaper follow the new layout
    [ -x "$HOME/.config/autorandr/postswitch" ] && AUTORANDR_CURRENT_PROFILE="$PROFILE" "$HOME/.config/autorandr/postswitch"
}

arrange() {
    [ "$N" -lt 2 ] && { notify_disp "Only one screen: nothing to arrange."; return; }
    if is_mirrored; then # first put them side by side, then arrange
        local -a args=(--output "${OUTPUTS[0]}" --auto --pos 0x0)
        local prev=${OUTPUTS[0]} o
        for o in "${OUTPUTS[@]:1}"; do args+=(--output "$o" --auto --right-of "$prev"); prev=$o; done
        xrandr "${args[@]}"; sleep 1
    fi
    show_numbers
    local screen ref dir rows idx
    screen=$(pick_screen "Move which screen?") || return
    [ -z "$screen" ] && return
    local sidx; for sidx in "${!OUTPUTS[@]}"; do [ "${OUTPUTS[$sidx]}" = "$screen" ] && break; done
    ref=$(pick_screen "Place $screen next to" "$sidx") || return
    [ -z "$ref" ] && return
    rows=("$ICON_LEFT  Left of $ref" "$ICON_RIGHT  Right of $ref" "$ICON_UP  Above $ref" "$ICON_DOWN  Below $ref")
    idx=$(printf '%s\n' "${rows[@]}" | menu "$screen" "" 4) || return
    case "$idx" in
        0) dir=--left-of ;; 1) dir=--right-of ;; 2) dir=--above ;; 3) dir=--below ;; *) return ;;
    esac
    hide_numbers
    xrandr --output "$screen" "$dir" "$ref"
    relayout   # tidy up (alignment, no gaps)
    save_layout
}

rotate() {
    show_numbers
    local screen idx rot
    screen=$(pick_screen "Rotate which screen?") || return
    [ -z "$screen" ] && return
    idx=$(printf '%s\n' \
        "$ICON_LANDSCAPE  Landscape (normal)" \
        "$ICON_CCW  Portrait, rotated counter-clockwise" \
        "$ICON_ROTATE  Portrait, rotated clockwise" \
        "$ICON_FLIP  Upside down" \
        | menu "$screen" "now: $(rotation_label "$(monitor_geometry "$screen" | awk '{print $5}')")" 4) || return
    case "$idx" in
        0) rot=normal ;; 1) rot=left ;; 2) rot=right ;; 3) rot=inverted ;; *) return ;;
    esac
    hide_numbers
    if is_mirrored; then
        xrandr --output "$screen" --rotate "$rot"
    else
        # Rotate first (the size changes), then re-line everything up from the new sizes
        xrandr --output "$screen" --rotate "$rot"
        relayout
    fi
    save_layout
}

# --- Main menu ---
if [ "$N" -ge 2 ]; then
    if is_mirrored; then CURRENT="mirrored"; else CURRENT="extended"; fi
    MESG="$N screens · now: $CURRENT"
    ROWS=("$ICON_EXTEND  Extend (side by side)" "$ICON_MIRROR  Mirror" "$ICON_ARRANGE  Arrange screens…" "$ICON_ROTATE  Rotate a screen…")
    ACTS=(extend mirror arrange rotate)
else
    MESG="1 screen: $(monitor_geometry "${OUTPUTS[0]}" | awk '{print $1 "x" $2}')"
    ROWS=("$ICON_ROTATE  Rotate screen…")
    ACTS=(rotate)
fi

show_numbers
idx=$(printf '%s\n' "${ROWS[@]}" | menu "Screens" "$MESG" "${#ROWS[@]}") || exit 0
[ -z "$idx" ] && exit 0
hide_numbers

case "${ACTS[$idx]}" in
    extend)
        # Saved profile matches these screens -> load it; otherwise arrange them first
        if autorandr --detected 2>/dev/null | grep -qx "$PROFILE"; then
            autorandr --load "$PROFILE"
        else
            arrange
        fi ;;
    mirror)  autorandr --load common ;;
    arrange) arrange ;;
    rotate)  rotate ;;
esac
