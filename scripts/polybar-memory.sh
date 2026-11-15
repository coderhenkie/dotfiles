#!/usr/bin/env bash
# ==========================================
# Polybar RAM Usage Module
# ==========================================
# Prints "<used%> (<used> GB)", same units as the disk module (1 GB = 1024^3 bytes).
# Used = MemTotal - MemAvailable (what the kernel can't hand out without swapping).
#
# Usage: polybar-memory.sh [-h|--help]

# No set -e: Polybar status poll script.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { avail = $2 }
     END { used = total - avail; printf "%d%% (%.1f GB)\n", used * 100 / total, used / 1048576 }' /proc/meminfo
