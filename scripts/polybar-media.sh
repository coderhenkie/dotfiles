#!/usr/bin/env bash
# Polybar media module: shows "<play/pause icon> Artist - Title" for the active MPRIS player
# (Spotify, Thorium/YouTube, ...). Prefers a playing player, then Spotify, then any paused one.
#   polybar-media.sh          -> follow mode (prints a line whenever something changes)
#   polybar-media.sh toggle   -> play/pause the shown player
#   polybar-media.sh next|previous

MAX_LEN=60
# Nerd Font glyphs, written as escapes so editors/tools can't strip them
ICON_PLAYING=$'\uf04b'   # nf-fa-play
ICON_PAUSED=$'\uf04c'    # nf-fa-pause

pick_player() {
    local players p status fallback=""
    players=$(playerctl -l 2>/dev/null) || return 1
    [ -z "$players" ] && return 1

    # 1. Anything that is playing (Spotify first)
    for p in $(grep -i '^spotify' <<<"$players") $(grep -iv '^spotify' <<<"$players"); do
        status=$(playerctl -p "$p" status 2>/dev/null)
        if [ "$status" = "Playing" ]; then echo "$p"; return 0; fi
        if [ "$status" = "Paused" ] && [ -z "$fallback" ]; then fallback="$p"; fi
    done

    # 2. Otherwise the first paused one (Spotify first)
    [ -n "$fallback" ] && { echo "$fallback"; return 0; }
    return 1
}

print_status() {
    local p status artist title text icon
    if ! p=$(pick_player); then
        echo ""
        return
    fi

    status=$(playerctl -p "$p" status 2>/dev/null)
    artist=$(playerctl -p "$p" metadata artist 2>/dev/null)
    title=$(playerctl -p "$p" metadata title 2>/dev/null)

    if [ -n "$artist" ] && [ -n "$title" ]; then
        text="$artist - $title"
    else
        text="${title:-$artist}"
    fi
    [ -z "$text" ] && { echo ""; return; }

    if [ "${#text}" -gt "$MAX_LEN" ]; then
        text="${text:0:$((MAX_LEN - 3))}..."
    fi
    # Keep song titles from being parsed as polybar format tags
    text=${text//%\{/% \{}

    if [ "$status" = "Playing" ]; then icon="$ICON_PLAYING"; else icon="$ICON_PAUSED"; fi
    echo "$icon  $text"
}

case "${1:-}" in
    toggle|next|previous)
        p=$(pick_player) && playerctl -p "$p" "${1/toggle/play-pause}"
        exit 0
        ;;
esac

command -v playerctl >/dev/null 2>&1 || { echo ""; exit 0; }

# Poll once a second; only print when the text changes so polybar doesn't redraw needlessly.
last="__init__"
while true; do
    current=$(print_status)
    if [ "$current" != "$last" ]; then
        echo "$current"
        last="$current"
    fi
    sleep 1
done
