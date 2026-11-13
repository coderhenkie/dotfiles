#!/usr/bin/env bash
# ==========================================
# Clipboard History (xclip + Rofi)
# ==========================================
# clipboard.sh daemon   Watches the clipboard and keeps the last 50 text entries.
#                       Started once per login from i3/config.
# clipboard.sh [menu]   Rofi picker ($mod+c): select an entry to copy it again.
#
# Privacy: history lives in $XDG_RUNTIME_DIR (RAM, private to you, wiped at logout)
# and is never written to disk. Passwords copied from Bitwarden also end up here
# until you clear the history (menu option) or log out. Images are not recorded.

HIST_DIR="${XDG_RUNTIME_DIR:-/tmp/clipboard-$UID}/clipboard-history"
MAX_ENTRIES=50
MAX_BYTES=100000
POLL_SECONDS=0.5

ICON_CLEAR=$'\U000F039F'  # nf-md-notification_clear_all
CLEAR_ROW="$ICON_CLEAR  Clear clipboard history"

export DISPLAY="${DISPLAY:-:0}"
mkdir -p "$HIST_DIR" && chmod 700 "$HIST_DIR"

daemon() {
    # Only one watcher per session
    exec 9>"$HIST_DIR/.lock"
    flock -n 9 || exit 0

    local last="" current hash file
    while true; do
        sleep "$POLL_SECONDS"
        # Only plain text; skip images and other binary targets
        xclip -o -selection clipboard -t TARGETS 2>/dev/null | grep -qx 'UTF8_STRING\|STRING\|text/plain' || continue
        current=$(xclip -o -selection clipboard -t UTF8_STRING 2>/dev/null) || continue
        [ -z "${current//[[:space:]]/}" ] && continue
        [ "${#current}" -gt "$MAX_BYTES" ] && continue
        hash=$(printf '%s' "$current" | sha1sum | cut -c1-16)
        [ "$hash" = "$last" ] && continue
        last="$hash"

        # New entry (or move an existing one to the top): file mtime = recency
        file="$HIST_DIR/$hash"
        printf '%s' "$current" > "$file"
        touch "$file"

        # Trim to the newest MAX_ENTRIES
        ls -1t "$HIST_DIR" | tail -n +$((MAX_ENTRIES + 1)) | while read -r old; do rm -f "$HIST_DIR/$old"; done
    done
}

menu() {
    local -a files
    mapfile -t files < <(ls -1t "$HIST_DIR" 2>/dev/null)

    # One row per entry (newest first, newlines shown as ⏎), then the "clear" row
    local index
    index=$( {
        local f preview
        for f in "${files[@]}"; do
            preview=$(head -c 400 "$HIST_DIR/$f")
            preview="${preview//$'\n'/ ⏎ }"
            preview="${preview//$'\t'/ }"
            echo "${preview:0:120}"
        done
        echo "$CLEAR_ROW"
    } | rofi -dmenu -i -p "Clipboard" -format i -no-custom \
        -theme-str 'window { width: 50%; } listview { lines: 12; }')
    [ -z "$index" ] || [ "$index" -lt 0 ] && exit 0

    if [ "$index" -ge "${#files[@]}" ]; then
        rm -f "$HIST_DIR"/[0-9a-f]*
        printf '' | xclip -selection clipboard
        notify-send -a "Clipboard" -u low "Clipboard history cleared" 2>/dev/null
        exit 0
    fi
    xclip -selection clipboard -i < "$HIST_DIR/${files[$index]}"
    touch "$HIST_DIR/${files[$index]}"
}

case "${1:-menu}" in
    daemon) daemon ;;
    menu)   menu ;;
    *) echo "Usage: $0 [menu|daemon]" >&2; exit 1 ;;
esac
