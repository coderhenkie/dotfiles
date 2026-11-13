#!/usr/bin/env bash
# ==========================================
# Power Menu (Rofi)
# ==========================================
# Lock / suspend / log out / reboot / shut down. Log out, reboot and shut down ask
# for confirmation first. Bound to $mod+Shift+e (replaces the old i3-nagbar prompt).

ICON_LOCK=$'\U000F033E'     # nf-md-lock
ICON_SUSPEND=$'\U000F04B2'  # nf-md-sleep
ICON_LOGOUT=$'\U000F0343'   # nf-md-logout
ICON_REBOOT=$'\U000F0709'   # nf-md-restart
ICON_SHUTDOWN=$'\U000F0425' # nf-md-power

LOCK="$ICON_LOCK  Lock"
SUSPEND="$ICON_SUSPEND  Suspend"
LOGOUT="$ICON_LOGOUT  Log out"
REBOOT="$ICON_REBOOT  Reboot"
SHUTDOWN="$ICON_SHUTDOWN  Shut down"

ROFI_THEME='window { width: 22%; } listview { lines: 5; }'

confirm() {
    local answer
    answer=$(printf 'No\nYes\n' | rofi -dmenu -i -p "$1?" -theme-str 'window { width: 22%; } listview { lines: 2; }')
    [ "$answer" = "Yes" ]
}

choice=$(printf '%s\n' "$LOCK" "$SUSPEND" "$LOGOUT" "$REBOOT" "$SHUTDOWN" \
    | rofi -dmenu -i -p "Power" -theme-str "$ROFI_THEME")

case "$choice" in
    "$LOCK")     ~/dotfiles/scripts/lock.sh ;;
    "$SUSPEND")  systemctl suspend ;;   # light-locker locks on suspend
    "$LOGOUT")   confirm "Log out"   && i3-msg exit ;;
    "$REBOOT")   confirm "Reboot"    && systemctl reboot ;;
    "$SHUTDOWN") confirm "Shut down" && systemctl poweroff ;;
esac
