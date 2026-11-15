#!/usr/bin/env bash
# ==========================================
# Picom Compositor Launcher
# ==========================================
# Start (or restart) picom with the backend that fits the machine:
#   bare metal -> glx     (GPU compositing: shadows, rounded corners, opacity off the CPU)
#   VM         -> xrender (CPU 2D; virtual GPUs often have no/slow OpenGL)
# Override: PICOM_BACKEND=glx|xrender picom-launch.sh
# If glx fails to start (broken/missing GL driver), falls back to xrender.
#
# Usage: picom-launch.sh [-h|--help]

# No set -e: pkill returns non-zero when picom is not running, and glx startup may fail before falling back to xrender.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/machine.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/machine.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need picom

conf="$HOME/.config/picom/picom.conf"

if [ -n "${PICOM_BACKEND:-}" ]; then
    backend="$PICOM_BACKEND"
elif machine_is_vm; then
    backend="xrender"
else
    backend="glx"
fi

# Replace a running instance (i3 exec_always on reload, or manual re-run)
pkill -u "$UID" -x picom 2>/dev/null || true
while pgrep -u "$UID" -x picom >/dev/null 2>&1; do sleep 0.1; done

if ! picom --config "$conf" --backend "$backend" -b 2>/dev/null && [ "$backend" != xrender ]; then
    picom --config "$conf" --backend xrender -b
fi
