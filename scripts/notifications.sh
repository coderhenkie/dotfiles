#!/usr/bin/env bash

# ==========================================
# Notification Manager (dunst + Rofi + Polybar)
# ==========================================
# notifications.sh [menu]   Rofi menu: silent mode, history, mute/unmute apps
# notifications.sh toggle   Toggle silent mode (dunst pause). Notifications that
#                           arrive while silent are held and shown when you turn it off.
# notifications.sh status   One-line status for the bottom Polybar
#
# Muted apps are stored as dunst rules in ~/.config/dunst/dunstrc.d/50-muted-apps.conf
# (machine-local and ignored by Git, like i3/hotkeys.conf). Muted notifications are
# never shown as a popup but still land in the history.

MUTE_FILE="$HOME/.config/dunst/dunstrc.d/50-muted-apps.conf"
ICON_ON=$'\U000F009A'     # nf-md-bell
ICON_OFF=$'\U000F009B'    # nf-md-bell_off
ICON_CLEAR=$'\U000F039F'  # nf-md-notification_clear_all
ICON_HISTORY=$'\U000F02DA' # nf-md-history

export DISPLAY="${DISPLAY:-:0}"

is_silent() { [ "$(dunstctl is-paused 2>/dev/null)" = "true" ]; }

# Muted app names (one per line), read from the appname lines of our rule file
muted_apps() {
    [ -f "$MUTE_FILE" ] || return 0
    sed -n 's/^[[:space:]]*appname = "\(.*\)"$/\1/p' "$MUTE_FILE"
}

# Rewrite the rule file from a list of app names on stdin, then reload dunst
write_muted_apps() {
    mkdir -p "$(dirname "$MUTE_FILE")"
    {
        echo "# Managed by ~/dotfiles/scripts/notifications.sh (\$mod+Shift+n)"
        echo "# Machine-local; ignored by Git. Edit via the menu or by hand."
        echo
        local app i=0
        while IFS= read -r app; do
            [ -z "$app" ] && continue
            i=$((i + 1))
            echo "[muted_app_$i]"
            echo "    appname = \"${app//\"/}\""
            echo "    skip_display = true"
            echo
        done
    } > "$MUTE_FILE.tmp"
    mv "$MUTE_FILE.tmp" "$MUTE_FILE"
    dunstctl reload >/dev/null 2>&1 || true
}

toggle_mute() {
    local app="$1"
    if muted_apps | grep -Fxq -- "$app"; then
        muted_apps | grep -Fxv -- "$app" | write_muted_apps
        notify-send -a "Notifications" "Unmuted" "$app"
    else
        { muted_apps; echo "$app"; } | sort -u | write_muted_apps
        notify-send -a "Notifications" "Muted" "$app (still kept in history)"
    fi
}

toggle_silent() {
    if is_silent; then
        dunstctl set-paused false
        local held
        held=$(dunstctl count waiting 2>/dev/null || echo 0)
        notify-send -a "Notifications" -u low "Silent mode off" \
            "$([ "${held:-0}" -gt 0 ] && echo "$held held notification(s) incoming" || echo "Notifications are back on")"
    else
        notify-send -a "Notifications" -u low -t 1500 "Silent mode on" "Notifications are held until you turn it off"
        # Give dunst a moment to show the confirmation before pausing
        sleep 1.6
        dunstctl set-paused true
    fi
}

status() {
    local accent
    accent=$(sed -n 's/^accent=//p' "$HOME/.cache/theme/current.theme" 2>/dev/null)
    accent="${accent:-#bd93f9}"
    if is_silent; then
        local waiting
        waiting=$(dunstctl count waiting 2>/dev/null || echo 0)
        if [ "${waiting:-0}" -gt 0 ]; then
            echo "%{F$accent}$ICON_OFF%{F-} $waiting"
        else
            echo "%{F$accent}$ICON_OFF%{F-}"
        fi
    else
        echo "%{F$accent}$ICON_ON%{F-}"
    fi
}

menu() {
    local silent_label
    if is_silent; then
        silent_label="$ICON_OFF  Silent mode: ON   (select to turn off)"
    else
        silent_label="$ICON_ON  Silent mode: OFF  (select to turn on)"
    fi

    # Apps seen in history + apps already muted
    local apps
    apps=$( {
        dunstctl history 2>/dev/null | jq -r '.data[0][]?.appname.data // empty' 2>/dev/null
        muted_apps
    } | grep -v '^$' | sort -u)

    local rows=()
    rows+=("$silent_label")
    rows+=("$ICON_HISTORY  Show last notification again")
    rows+=("$ICON_CLEAR  Clear notification history")
    local app
    while IFS= read -r app; do
        [ -z "$app" ] && continue
        if muted_apps | grep -Fxq -- "$app"; then
            rows+=("$ICON_OFF  [muted]  $app")
        else
            rows+=("$ICON_ON  [shown]  $app")
        fi
    done <<< "$apps"

    local choice
    choice=$(printf '%s\n' "${rows[@]}" | rofi -dmenu -i -p "Notifications" \
        -mesg "Select an app to mute/unmute it  │  type a name + Enter to mute an app not listed" \
        -theme-str 'window { width: 42%; } listview { lines: 10; }')
    [ -z "$choice" ] && exit 0

    case "$choice" in
        "$silent_label")                 toggle_silent ;;
        *"Show last notification again") dunstctl history-pop ;;
        *"Clear notification history")  dunstctl history-clear; notify-send -a "Notifications" -u low "History cleared" ;;
        *"  [muted]  "*)                 toggle_mute "${choice#*  \[muted\]  }" ;;
        *"  [shown]  "*)                 toggle_mute "${choice#*  \[shown\]  }" ;;
        *)                               toggle_mute "$choice" ;;  # free text: mute a new app name
    esac
}

case "${1:-menu}" in
    toggle) toggle_silent ;;
    status) status ;;
    menu)   menu ;;
    *) echo "Usage: $0 [menu|toggle|status]" >&2; exit 1 ;;
esac
