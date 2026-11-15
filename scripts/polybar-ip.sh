#!/usr/bin/env bash
# ==========================================
# Polybar Local IPv4 Module
# ==========================================
# Prints local IPv4 (Wi-Fi or Ethernet), falling back to hostname -I, else "offline".
#
# Usage: polybar-ip.sh [-h|--help]

# No set -e: ip route and hostname may return non-zero when offline.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')
[ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{ print $1 }')
echo "${ip:-offline}"
