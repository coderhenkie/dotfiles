#!/usr/bin/env bash
# Polybar local IPv4 (Wi-Fi or Ethernet), falling back to hostname -I, else "offline"
ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')
[ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{ print $1 }')
echo "${ip:-offline}"
