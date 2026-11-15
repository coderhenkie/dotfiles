#!/usr/bin/env bash
# ==========================================
# Clipboard History (xclip + Rofi)
# ==========================================
# menu-clipboard.sh daemon   Watches the clipboard and keeps the last 50 text entries.
#                            Started once per login from i3/config.
# menu-clipboard.sh [menu]   Rofi picker ($mod+c): select an entry to copy it again.
#
# Privacy: history lives in runtime_dir (RAM when $XDG_RUNTIME_DIR is set, mode 0700)
# and skips entries marked with x-kde-passwordManagerHint as well as images/binary targets.
#
# Usage: menu-clipboard.sh [menu|daemon|-h|--help]

# No set -e: xclip returns non-zero when the clipboard is empty or holds non-text data, and rofi returns non-zero on Esc.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need xclip
i3_env

HIST_DIR="$(runtime_dir)/clipboard-history"
MAX_ENTRIES=50
MAX_BYTES=100000
POLL_SECONDS=0.5

ICON_CLEAR=$'\U000F039F'  # nf-md-notification_clear_all
CLEAR_ROW="$ICON_CLEAR  Clear clipboard history"

mkdir -p "$HIST_DIR" && chmod 700 "$HIST_DIR"

# Print history entry filenames (newest first) without parsing ls
list_entries() {
    find "$HIST_DIR" -maxdepth 1 -type f -name '[0-9a-f]*' -printf '%T@\t%f\n' 2>/dev/null \
        | sort -rn | cut -f2-
}

daemon() {
    single_instance clipboard

    local last="" targets current hash file
    while session_alive; do
        sleep "$POLL_SECONDS"
        targets=$(xclip -o -selection clipboard -t TARGETS 2>/dev/null) || continue
        # Skip password manager entries (Bitwarden, KeePassXC, etc. advertise x-kde-passwordManagerHint)
        grep -qx 'x-kde-passwordManagerHint' <<< "$targets" && continue
        # Only plain text; skip images and other binary targets
        grep -qx 'UTF8_STRING\|STRING\|text/plain' <<< "$targets" || continue
        current=$(xclip -o -selection clipboard -t UTF8_STRING 2>/dev/null) || continue
        [ -z "${current//[[:space:]]/}" ] && continue
        [ "${#current}" -gt "$MAX_BYTES" ] && continue
        hash=$(printf '%s' "$current" | sha1sum | cut -c1-16)
        [ "$hash" = "$last" ] && continue
        last="$hash"

        # New entry (or move an existing one to the top): file mtime = recency
        file="$HIST_DIR/$hash"
        (umask 077 && printf '%s' "$current" > "$file")
        touch "$file"

        # Trim to the newest MAX_ENTRIES
        list_entries | tail -n +$((MAX_ENTRIES + 1)) | while IFS= read -r old; do
            [ -n "$old" ] && rm -f "$HIST_DIR/$old"
        done
    done
}

menu() {
    need rofi
    local -a files
    mapfile -t files < <(list_entries)

    # One row per entry (newest first, newlines shown as ⏎), then the "clear" row
    local index
    index=$( {
        local f preview
        for f in "${files[@]}"; do
            preview=$(head -c 400 "$HIST_DIR/$f" 2>/dev/null || true)
            preview="${preview//$'\n'/ ⏎ }"
            preview="${preview//$'\t'/ }"
            echo "${preview:0:120}"
        done
        echo "$CLEAR_ROW"
    } | rofi -dmenu -i -p "Clipboard" -format i -no-custom \
        -theme-str 'window { width: 50%; } listview { lines: 12; }')
    if [ -z "$index" ] || [ "$index" -lt 0 ]; then
        exit 0
    fi

    if [ "$index" -ge "${#files[@]}" ]; then
        rm -f "$HIST_DIR"/[0-9a-f]*
        printf '' | xclip -selection clipboard
        notify -a "Clipboard" -u low "Clipboard history cleared"
        exit 0
    fi
    xclip -selection clipboard -i < "$HIST_DIR/${files[$index]}"
    touch "$HIST_DIR/${files[$index]}"
}

case "${1:-menu}" in
    daemon) daemon ;;
    menu)   menu ;;
    *) help_from_header; exit 1 ;;
esac
