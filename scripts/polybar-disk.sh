#!/usr/bin/env bash
# Polybar disk usage: "<used%> (<used> GB/<total> GB)" across all real mounted filesystems
df -B1 --total -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay 2>/dev/null \
    | awk 'END { g = 1024 ^ 3; printf "%s (%.1f GB/%.1f GB)\n", $5, $3 / g, $2 / g }'
