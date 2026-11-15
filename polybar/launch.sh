#!/usr/bin/env bash
# ==========================================
# Polybar Multi-Monitor Launcher
# ==========================================
# Terminates any running Polybar instances for the current user and launches
# a top and bottom bar on every connected monitor (with the system tray on the
# primary monitor's top bar).
#
# Usage: launch.sh [-h|--help]

# No set -e: pkill/polybar --list-monitors may return non-zero when no bar or monitor is active.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=../scripts/lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../scripts/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need polybar

# Serialize: i3's exec_always and autorandr's postswitch hook both run this at
# login; without a lock they race past pkill and start duplicate bars.
exec 9>"$(runtime_dir)/polybar-launch.lock"
flock 9

# UI scale snippet (DPI + height) must exist before Polybar reads its config
"$DOTFILES_DIR/scripts/ui-scale.sh" files

# Terminate any running Polybar instances belonging to this user
pkill -u "$UID" -x polybar 2>/dev/null || true

# Wait until the processes have completely shut down
while pgrep -u "$UID" -x polybar >/dev/null 2>&1; do sleep 0.2; done

# Launch a Top and Bottom bar on every screen (scripts/monitor-layout.sh arranges them).
# The tray can only exist once, so only the primary screen's top bar gets it.
PRIMARY=$(polybar --list-monitors 2>/dev/null | awk -F: '/\(primary\)/ {print $1; exit}' || true)
MONITORS=$(polybar --list-monitors 2>/dev/null | cut -d: -f1 || true)
[ -z "$MONITORS" ] && MONITORS="-"   # fallback: let Polybar pick
[ -z "$PRIMARY" ] && PRIMARY=$(head -n1 <<< "$MONITORS")

# Intentional word-splitting over newline-separated xrandr output names (output names never contain whitespace)
# shellcheck disable=SC2086
for m in $MONITORS; do
    tray=""
    [ "$m" = "$PRIMARY" ] && tray="tray"
    [ "$m" = "-" ] && m=""
    MONITOR="$m" TRAY_MODULE="$tray" setsid polybar top -c "$HOME/.config/polybar/config.ini" >/dev/null 2>&1 < /dev/null 9>&- &
    MONITOR="$m" setsid polybar bottom -c "$HOME/.config/polybar/config.ini" >/dev/null 2>&1 < /dev/null 9>&- &
done
