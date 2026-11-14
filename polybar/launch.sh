#!/usr/bin/env bash

# Serialize: i3's exec_always and autorandr's postswitch hook both run this at
# login; without a lock they race past killall and start duplicate bars.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/polybar-launch.lock"
flock 9

# UI scale snippet (DPI + height) must exist before Polybar reads its config
~/dotfiles/scripts/ui-scale.sh files

# Terminate any running Polybar instances
killall -q polybar

# Wait until the processes have completely shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

# Launch both Top and Bottom Polybar bars
setsid polybar top -c ~/.config/polybar/config.ini >/dev/null 2>&1 < /dev/null 9>&- &
setsid polybar bottom -c ~/.config/polybar/config.ini >/dev/null 2>&1 < /dev/null 9>&- &
