#!/usr/bin/env bash
# ==========================================
# Default Applications (xdg-mime)
# ==========================================
# Web links -> Thorium, PDFs -> Zathura, images -> imv, audio/video -> mpv,
# folders -> Thunar. Writes ~/.config/mimeapps.list via xdg-mime; safe to re-run.
# Only sets a default when that app's .desktop file is installed.
#
# Usage: default-apps.sh [-h|--help]

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need xdg-mime

has_desktop() {
    [ -f "$HOME/.local/share/applications/$1" ] || [ -f "/usr/share/applications/$1" ]
}

set_default() {
    local app="$1"; shift
    if ! has_desktop "$app"; then
        warn "$app not installed; skipping its file types."
        return
    fi
    xdg-mime default "$app" "$@" || warn "xdg-mime: could not set $app as default (continuing)."
}

set_default thorium.desktop \
    x-scheme-handler/http x-scheme-handler/https x-scheme-handler/about x-scheme-handler/unknown \
    text/html application/xhtml+xml
if has_desktop thorium.desktop && have xdg-settings; then
    xdg-settings set default-web-browser thorium.desktop 2>/dev/null || true
fi

set_default org.pwmt.zathura.desktop application/pdf application/epub+zip

set_default imv.desktop \
    image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml image/avif image/heif

set_default mpv.desktop \
    video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg \
    audio/mpeg audio/mp4 audio/flac audio/ogg audio/x-wav audio/wav audio/opus audio/aac

set_default thunar.desktop inode/directory

ok "Default applications set."
