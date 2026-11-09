#!/usr/bin/env bash

# Sluit eventuele openstaande Polybar processen
killall -q polybar

# Wacht tot de processen echt weg zijn
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Start de balk (we noemen de balk 'main')
polybar main -c ~/.config/polybar/config.ini &
