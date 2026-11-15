#!/usr/bin/env bash
# ==========================================
# Polybar Disk Usage Module
# ==========================================
# Prints "<used%> (<used> GB/<total> GB)" across all real mounted filesystems.
#
# Usage: polybar-disk.sh [-h|--help]

# No set -e: Polybar status poll script.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

df -B1 --total -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay 2>/dev/null \
    | awk 'END { g = 1024 ^ 3; printf "%s (%.1f GB/%.1f GB)\n", $5, $3 / g, $2 / g }'
