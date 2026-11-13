#!/usr/bin/env bash

# UI scale snippet (DPI + height) must exist before Polybar reads its config
~/dotfiles/scripts/ui-scale.sh files

# Terminate any running Polybar instances
killall -q polybar

# Wait until the processes have completely shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

# Launch both Top and Bottom Polybar bars
setsid polybar top -c ~/.config/polybar/config.ini >/dev/null 2>&1 < /dev/null &
setsid polybar bottom -c ~/.config/polybar/config.ini >/dev/null 2>&1 < /dev/null &
