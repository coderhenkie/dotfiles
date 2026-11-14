#!/usr/bin/env bash
# Start (or restart) picom with the backend that fits the machine:
#   bare metal -> glx     (GPU compositing: shadows, rounded corners, opacity off the CPU)
#   VM         -> xrender (CPU 2D; virtual GPUs often have no/slow OpenGL)
# Override: PICOM_BACKEND=glx|xrender picom-launch.sh
# If glx fails to start (broken/missing GL driver), falls back to xrender.

conf=~/.config/picom/picom.conf

if [ -n "$PICOM_BACKEND" ]; then
    backend=$PICOM_BACKEND
elif systemd-detect-virt --vm --quiet 2>/dev/null; then
    backend=xrender
else
    backend=glx
fi

# Replace a running instance (i3 exec_always on reload, or manual re-run)
killall -q picom
while pgrep -u "$UID" -x picom >/dev/null; do sleep 0.1; done

if ! picom --config "$conf" --backend "$backend" -b 2>/dev/null && [ "$backend" != xrender ]; then
    picom --config "$conf" --backend xrender -b
fi
