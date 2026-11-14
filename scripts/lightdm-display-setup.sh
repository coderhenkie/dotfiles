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
# @CONF@ (the user's ~/.config/autorandr/main/config). The config is only read as data.
# Always exits 0: a failing display-setup-script would stop LightDM from showing the screen.

/usr/bin/setxkbmap -option caps:swapescape 2>/dev/null   # Caps Lock <-> Escape, like the session

CONF="@CONF@"
[ -r "$CONF" ] && command -v xrandr >/dev/null || exit 0

args=() wanted=() out=""
while read -r key val _; do
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
connected=$(xrandr --query | awk '$2 == "connected" {print $1}' | sort)
[ -n "${wanted[*]}" ] && [ "$connected" = "$(printf '%s\n' "${wanted[@]}" | sort)" ] || exit 0

xrandr "${args[@]}" 2>/dev/null
exit 0
