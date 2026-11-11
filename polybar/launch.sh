#!/usr/bin/env bash

# Terminate any running Polybar instances
killall -q polybar

# Wait until the processes have completely shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch the main bar
polybar main -c ~/.config/polybar/config.ini &
