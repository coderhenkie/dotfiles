#!/bin/bash
# ==========================================
# LightDM display setup: lock/login screen uses your monitor layout
# ==========================================
# The lock screen (light-locker) and login screen are LightDM's greeter on its own X server, which
# knows nothing about the layout made with $mod+p (autorandr profile `main`): a portrait screen
# would come up landscape there. LightDM runs this as root (display-setup-script) every time a
# greeter starts; it applies the saved `main` layout when exactly those screens are connected.
#
# Installed root-owned to /usr/local/sbin/ by scripts/lockscreen-setup.sh, which fills in
# @CONF@ (the user's ~/.config/autorandr/main/config) and @UID@ (that user's uid).
# Runs as root, so the user-writable config is treated as untrusted data: it must be a regular
# file (not a symlink) owned by @UID@, and every value is validated before it reaches xrandr.
# Any doubt -> the layout is not applied (xrandr defaults).
# Plain /bin/bash with absolute tool paths on purpose: root, minimal environment, no $PATH lookups.
# Always exits 0: a failing display-setup-script would stop LightDM from showing the screen.

/usr/bin/setxkbmap -option caps:swapescape 2>/dev/null   # Caps Lock <-> Escape, like the session

CONF="@CONF@"
OWNER_UID="@UID@"
XRANDR=/usr/bin/xrandr

[ -x "$XRANDR" ] || exit 0
[ -f "$CONF" ] && [ ! -L "$CONF" ] || exit 0
[ "$(/usr/bin/stat -c %u "$CONF" 2>/dev/null)" = "$OWNER_UID" ] || exit 0

valid() { # <key> <value>
    case "$1" in
        output)    [[ "$2" =~ ^[A-Za-z0-9-]+$ ]] ;;
        mode|pos)  [[ "$2" =~ ^[0-9]+x[0-9]+$ ]] ;;
        rate)      [[ "$2" =~ ^[0-9]+(\.[0-9]+)?$ ]] ;;
        rotate)    [[ "$2" =~ ^(normal|left|right|inverted)$ ]] ;;
        *)         return 1 ;;
    esac
}

args=() wanted=() out=""
while read -r key val _; do
    case "$key" in
        output|mode|pos|rate|rotate) valid "$key" "$val" || exit 0 ;;
    esac
    case "$key" in
        output)  out=$val; args+=(--output "$val") ;;
        off)     args+=(--off) ;;
        mode)    args+=(--mode "$val"); wanted+=("$out") ;;
        pos)     args+=(--pos "$val") ;;
        rate)    args+=(--rate "$val") ;;
        rotate)  args+=(--rotate "$val") ;;
        primary) args+=(--primary) ;;
    esac
done < "$CONF"

# Only when the connected screens are exactly the ones in the profile (other monitors: xrandr default)
connected=$("$XRANDR" --query | /usr/bin/awk '$2 == "connected" {print $1}' | /usr/bin/sort)
[ -n "${wanted[*]}" ] && [ "$connected" = "$(printf '%s\n' "${wanted[@]}" | /usr/bin/sort)" ] || exit 0

"$XRANDR" "${args[@]}" 2>/dev/null
exit 0
