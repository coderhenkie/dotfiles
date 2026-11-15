#!/usr/bin/env bash
# ==========================================
# Restart Spotify, keep the music going
# ==========================================
# Spotify only loads a Spicetify theme at startup, so apply-theme.sh restarts it after a theme
# change. If it was playing, the same track continues from the same position: Spotify restores its
# last session on startup; if that isn't the same track, it is opened again by its URI. A few
# seconds of silence, nothing to click. Does nothing when Spotify isn't running.
#
# Usage: spotify-restart.sh [-h|--help]

# No set -e: playerctl returns non-zero while Spotify is restarting and registering on D-Bus.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

P=(playerctl -p spotify)
pgrep -x spotify >/dev/null 2>&1 || exit 0

status=$("${P[@]}" status 2>/dev/null || true)
url=$("${P[@]}" metadata xesam:url 2>/dev/null || true)       # https://open.spotify.com/track/<id>
pos=$("${P[@]}" position 2>/dev/null || true)                 # seconds, e.g. 83.412

pkill -x spotify 2>/dev/null || true
for _ in $(seq 50); do pgrep -x spotify >/dev/null 2>&1 || break; sleep 0.1; done
setsid spotify >/dev/null 2>&1 </dev/null &

[ "$status" = "Playing" ] || exit 0

# Wait until Spotify's media controls (MPRIS) are back
for _ in $(seq 40); do "${P[@]}" status >/dev/null 2>&1 && break; sleep 0.5; done
sleep 1

if [ -n "$url" ] && [ "$("${P[@]}" metadata xesam:url 2>/dev/null || true)" != "$url" ]; then
    # https://open.spotify.com/<type>/<id>?... -> spotify:<type>:<id>
    uri=$(sed -E 's#^https?://open\.spotify\.com/([a-z]+)/([A-Za-z0-9]+).*#spotify:\1:\2#' <<< "$url")
    "${P[@]}" open "$uri" 2>/dev/null || true
    sleep 1.5
fi
"${P[@]}" play 2>/dev/null || true
sleep 0.5
if [ -n "$pos" ]; then
    "${P[@]}" position "${pos%.*}" 2>/dev/null || true
fi
exit 0
