#!/usr/bin/env bash
# Polybar RAM usage: "<used%> (<used> GB)", same units as the disk module (1 GB = 1024^3 bytes).
# Used = MemTotal - MemAvailable (what the kernel can't hand out without swapping).
awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { avail = $2 }
     END { used = total - avail; printf "%d%% (%.1f GB)\n", used * 100 / total, used / 1048576 }' /proc/meminfo
