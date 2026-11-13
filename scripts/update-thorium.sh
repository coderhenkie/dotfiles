#!/usr/bin/env bash
# ==========================================
# Thorium Browser Updater (checksum-verified AppImage)
# ==========================================
# Installs or updates ~/appimages/thorium.appimage to the newest Thorium Linux build.
#
# Sources (the newest version of the two wins):
#   - Alex313031/Thorium  official repo (Linux builds stalled at M138 in 2025)
#   - gz83/thorium        builds by a Thorium collaborator, linked from the official
#                         repo's release notes while the original developer is away
# Picks the AVX2 build when the CPU supports it, otherwise SSE4. Every download is
# verified against GitHub's published SHA-256 before it replaces the old AppImage;
# a running Thorium keeps working and uses the new version after a restart.
#
# Runs from setup.sh and at i3 login (--quiet: only notifies when it updated).
#   update-thorium.sh [--quiet]

set -u

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

APPIMAGE_DIR="$HOME/appimages"
APPIMAGE="$APPIMAGE_DIR/thorium.appimage"
VERSION_FILE="$APPIMAGE_DIR/thorium.version"
LOCAL_BIN="$HOME/.local/bin"
SOURCES=("Alex313031/Thorium" "gz83/thorium")

# shellcheck source=lib/github-download.sh
source "$(dirname "$(readlink -f "$0")")/lib/github-download.sh"

say() { [ "$QUIET" = 1 ] || echo "$@"; }

if grep -q avx2 /proc/cpuinfo 2>/dev/null; then ISA="AVX2"; else ISA="SSE4"; fi
REGEX="^Thorium_Browser_[0-9.]+_${ISA}\\.AppImage$"

# Find the newest build across all sources
best_ver="" best_info="" best_repo=""
for repo in "${SOURCES[@]}"; do
    info=$(gh_find_asset "$repo" "$REGEX") || continue
    IFS='|' read -r _ name _ _ <<< "$info"
    ver=$(sed -E 's/^Thorium_Browser_([0-9.]+)_.*/\1/' <<< "$name")
    newest=$(printf '%s\n%s\n' "${best_ver:-0}" "$ver" | sort -V | tail -n 1)
    if [ "$ver" != "$best_ver" ] && [ "$newest" = "$ver" ]; then
        best_ver="$ver" best_info="$info" best_repo="$repo"
    fi
done

if [ -z "$best_ver" ]; then
    say "[!] Could not find a Thorium $ISA AppImage (offline or GitHub API rate limit)." >&2
    exit 1
fi

# Installed version: from our version file, or ask the AppImage itself
current=""
[ -f "$VERSION_FILE" ] && current=$(cat "$VERSION_FILE")
if [ -z "$current" ] && [ -x "$APPIMAGE" ]; then
    current=$("$APPIMAGE" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){3}' | head -n 1)
fi

if [ -n "$current" ] && [ "$(printf '%s\n%s\n' "$current" "$best_ver" | sort -V | tail -n 1)" = "$current" ]; then
    say "[OK] Thorium is up to date ($current)."
    ln -sf "$APPIMAGE" "$LOCAL_BIN/thorium"
    exit 0
fi

say " -> Installing Thorium $best_ver ($ISA) from $best_repo (installed: ${current:-none})..."
IFS='|' read -r _ _ url digest <<< "$best_info"
if [ "$QUIET" = 1 ]; then
    gh_download_verified "$url" "$digest" "$APPIMAGE" >/dev/null 2>&1
else
    gh_download_verified "$url" "$digest" "$APPIMAGE"
fi || {
    [ "$QUIET" = 1 ] && notify-send -a "Thorium" -u critical "Thorium update failed" "Could not download or verify $best_ver" 2>/dev/null
    exit 1
}

chmod u+x "$APPIMAGE"
echo "$best_ver" > "$VERSION_FILE"
mkdir -p "$LOCAL_BIN"
ln -sf "$APPIMAGE" "$LOCAL_BIN/thorium"
say "[OK] Thorium $best_ver installed."
[ "$QUIET" = 1 ] && notify-send -a "Thorium" "Thorium updated to $best_ver" "Restart the browser to use the new version" 2>/dev/null
exit 0
