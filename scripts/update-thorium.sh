#!/usr/bin/env bash
# ==========================================
# Thorium Browser Updater (checksum-verified AppImage)
# ==========================================
# Installs or updates ~/appimages/thorium.appimage to the newest Thorium Linux build.
#
# Sources (the newest version wins):
#   - Alex313031/Thorium  official repo (Linux builds stalled at M138 in 2025)
#   - gz83/thorium        builds by a Thorium collaborator, linked from the official
#                         repo's release notes while the original developer is away
# A build that is NOT from the official repo is only installed after you confirm it:
# on the terminal (y/N), or with a notification (click = install, "Skip" = never ask
# again for that version, closing it = ask again next time). Without a way to ask
# (no terminal, no notification daemon) it is not installed; the newest official
# build is used instead when that is newer than the installed one.
# The chosen source is printed and stored in ~/appimages/thorium.source.
#
# Picks the AVX2 build when the CPU supports it, otherwise SSE4. Every download is
# verified against GitHub's published SHA-256 before it replaces the old AppImage;
# a running Thorium keeps working and uses the new version after a restart.
#
# Runs from setup.sh and at i3 login (--quiet: only notifies when it updated).
#   update-thorium.sh [--quiet] [-h|--help]

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/github-download.sh
source "$SCRIPT_DIR/lib/github-download.sh"

QUIET=0
case "${1:-}" in
    --quiet)   QUIET=1 ;;
    -h|--help) help_from_header; exit 0 ;;
    "")        ;;
    *)         die "Unknown option: $1 (see --help)" ;;
esac

APPIMAGE_DIR="$HOME/appimages"
APPIMAGE="$APPIMAGE_DIR/thorium.appimage"
VERSION_FILE="$APPIMAGE_DIR/thorium.version"
SOURCE_FILE="$APPIMAGE_DIR/thorium.source"
SKIP_FILE="$APPIMAGE_DIR/thorium.skip"     # unofficial versions you chose to skip
LOCAL_BIN="$HOME/.local/bin"
OFFICIAL="Alex313031/Thorium"
SOURCES=("$OFFICIAL" "gz83/thorium")

say() { [ "$QUIET" = 1 ] || echo "$@"; }
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]; }  # $1 > $2

if grep -q avx2 /proc/cpuinfo 2>/dev/null; then ISA="AVX2"; else ISA="SSE4"; fi
REGEX="^Thorium_Browser_[0-9.]+_${ISA}\\.AppImage$"

# Newest build overall, and newest official build (fallback when an unofficial one is declined)
best_ver="" best_info="" best_repo="" official_ver="" official_info=""
for repo in "${SOURCES[@]}"; do
    info=$(gh_find_asset "$repo" "$REGEX") || continue
    IFS='|' read -r _ name _ _ <<< "$info"
    ver=$(sed -E 's/^Thorium_Browser_([0-9.]+)_.*/\1/' <<< "$name")
    if [ "$repo" = "$OFFICIAL" ]; then
        official_ver="$ver" official_info="$info"
    fi
    if [ -z "$best_ver" ] || newer "$ver" "$best_ver"; then
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
    current=$("$APPIMAGE" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){3}' | head -n 1 || true)
fi

up_to_date() {
    say "[OK] Thorium is up to date (${current:-not installed})."
    [ -x "$APPIMAGE" ] && ln -sfn "$APPIMAGE" "$LOCAL_BIN/thorium"
    exit 0
}

[ -n "$current" ] && ! newer "$best_ver" "$current" && up_to_date

# confirm_unofficial <version> <repo>: 0 = install, 1 = not now, 2 = skip this version for good
confirm_unofficial() {
    local ver="$1" repo="$2" answer
    if [ "$QUIET" = 0 ] && ( : </dev/tty ) 2>/dev/null; then
        printf '[?] Thorium %s comes from %s, not the official %s. Install it? [y/N] ' "$ver" "$repo" "$OFFICIAL" >/dev/tty
        IFS= read -r answer </dev/tty || answer=""
        case "$answer" in y|Y|yes|j|J|ja) return 0 ;; *) return 1 ;; esac
    fi
    if [ -n "${DISPLAY:-}" ] && have notify-send; then
        answer=$(notify-send -a "Thorium" -u normal -t 0 --wait \
            --action=default=Install --action=skip="Skip this version" \
            "Thorium $ver available from unofficial builds" \
            "Built by $repo, not the official $OFFICIAL. Click to install; close to decide later." 2>/dev/null) || answer=""
        case "$answer" in
            default) return 0 ;;
            skip)    return 2 ;;
            *)       return 1 ;;
        esac
    fi
    warn "Thorium $ver from $repo needs confirmation, but there is no terminal or notification to ask; not installed."
    return 1
}

if [ "$best_repo" != "$OFFICIAL" ]; then
    if grep -Fxq -- "$best_ver" "$SKIP_FILE" 2>/dev/null; then
        say "[!] Thorium $best_ver from $best_repo was skipped earlier; not asking again."
        rc=1
    else
        rc=0; confirm_unofficial "$best_ver" "$best_repo" || rc=$?
        [ "$rc" = 2 ] && echo "$best_ver" >> "$SKIP_FILE"
    fi
    if [ "$rc" != 0 ]; then
        # Fall back to the newest official build when that is still an update
        if [ -n "$official_ver" ] && { [ -z "$current" ] || newer "$official_ver" "$current"; }; then
            best_ver="$official_ver" best_info="$official_info" best_repo="$OFFICIAL"
        else
            up_to_date
        fi
    fi
fi

say " -> Installing Thorium $best_ver ($ISA) from $best_repo (installed: ${current:-none})..."
IFS='|' read -r _ _ url digest <<< "$best_info"
if [ "$QUIET" = 1 ]; then
    gh_download_verified "$url" "$digest" "$APPIMAGE" >/dev/null 2>&1
else
    gh_download_verified "$url" "$digest" "$APPIMAGE"
fi || {
    if [ "$QUIET" = 1 ]; then
        notify -a "Thorium" -u critical "Thorium update failed" "Could not download or verify $best_ver"
    fi
    exit 1
}

chmod u+x "$APPIMAGE"
echo "$best_ver" > "$VERSION_FILE"
echo "$best_repo" > "$SOURCE_FILE"
mkdir -p "$LOCAL_BIN"
ln -sfn "$APPIMAGE" "$LOCAL_BIN/thorium"
say "[OK] Thorium $best_ver installed (source: $best_repo)."
if [ "$QUIET" = 1 ]; then
    notify -a "Thorium" "Thorium updated to $best_ver" "Source: $best_repo. Restart the browser to use the new version"
fi
exit 0
