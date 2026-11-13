#!/usr/bin/env bash
# ==========================================
# Verified GitHub release downloads (sourced by setup.sh & update-thorium.sh)
# ==========================================
# GitHub publishes a SHA-256 digest for every release asset. These helpers only
# accept a download when its checksum matches that digest, and download into a
# private temp file first so a failed or tampered download never replaces anything.

# gh_find_asset <owner/repo> <asset-name-regex>
#   Prints "<version-tag>|<asset-name>|<download-url>|<sha256-digest>" for the newest
#   non-prerelease release that has a matching asset. Returns 1 if none is found.
#   Uses $GITHUB_TOKEN when set (5000 instead of 60 API requests per hour).
gh_find_asset() {
    local repo="$1" regex="$2" json auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    json=$(curl -sSL "${auth[@]}" "https://api.github.com/repos/$repo/releases?per_page=20" 2>/dev/null)
    if jq -e 'type == "object" and (.message // "" | test("rate limit"))' <<< "$json" >/dev/null 2>&1; then
        echo "[!] GitHub API rate limit reached (60 requests/hour without GITHUB_TOKEN); try again later." >&2
        return 1
    fi
    jq -r --arg re "$regex" '
            [ .[] | select(.prerelease | not) as $r
              | $r.assets[] | select(.name | test($re))
              | "\($r.tag_name)|\(.name)|\(.browser_download_url)|\(.digest // "")" ][0] // empty' <<< "$json" 2>/dev/null \
        | grep . || return 1
}

# gh_download_verified <url> <sha256:digest> <destination>
#   Downloads <url>, verifies it against <digest>, then atomically moves it to <destination>.
gh_download_verified() {
    local url="$1" digest="$2" dest="$3" tmp actual
    if [[ "$digest" != sha256:* ]]; then
        echo "[!] No SHA-256 checksum published for $(basename "$url"); refusing to install it." >&2
        return 1
    fi
    mkdir -p "$(dirname "$dest")"
    tmp=$(mktemp "$(dirname "$dest")/.download.XXXXXX") || return 1
    if ! curl -fL --retry 2 --progress-bar -o "$tmp" "$url"; then
        rm -f "$tmp"
        echo "[!] Download failed: $url" >&2
        return 1
    fi
    actual="sha256:$(sha256sum "$tmp" | cut -d' ' -f1)"
    if [ "$actual" != "$digest" ]; then
        rm -f "$tmp"
        echo "[!] Checksum mismatch for $(basename "$url") (expected $digest, got $actual); file discarded." >&2
        return 1
    fi
    mv -f "$tmp" "$dest"
    echo "[OK] Verified $(basename "$url") (${digest:0:19}...)"
}

# gh_check_update <owner/repo> <asset-name-regex> <installed-version>
#   Looks up the newest matching release and compares it with <installed-version>
#   (leading "v" ignored; empty = not installed). Sets GH_LATEST_VERSION, GH_URL and
#   GH_DIGEST. Returns 0 when an install/update is needed, 1 when already up to date,
#   2 when the release could not be looked up (offline, API rate limit).
gh_check_update() {
    local repo="$1" regex="$2" current="${3#v}" info tag
    info=$(gh_find_asset "$repo" "$regex") || return 2
    IFS='|' read -r tag _ GH_URL GH_DIGEST <<< "$info"
    GH_LATEST_VERSION="${tag#v}"
    [ -z "$current" ] && return 0
    [ "$(printf '%s\n%s\n' "$current" "$GH_LATEST_VERSION" | sort -V | tail -n 1)" = "$current" ] && return 1
    return 0
}

# gh_install_latest <owner/repo> <asset-name-regex> <destination>
#   Convenience wrapper: find the newest matching asset and download it verified.
gh_install_latest() {
    local info
    info=$(gh_find_asset "$1" "$2") || { echo "[!] No release asset matching '$2' found in $1." >&2; return 1; }
    IFS='|' read -r _ _ url digest <<< "$info"
    gh_download_verified "$url" "$digest" "$3"
}

# gh_install_latest_sumfile <owner/repo> <asset-name> <checksum-file-asset> <destination>
#   Same guarantee as gh_install_latest, without the (rate-limited) GitHub API: downloads the
#   checksum list the project publishes with every release (e.g. nerd-fonts' SHA-256.txt)
#   from the plain releases/latest/download URL and verifies <asset-name> against it.
gh_install_latest_sumfile() {
    local repo="$1" asset="$2" sumfile="$3" dest="$4" base sum
    base="https://github.com/$repo/releases/latest/download"
    sum=$(curl -fsSL --retry 2 "$base/$sumfile" 2>/dev/null \
        | awk -v a="$asset" '$2 == a || $2 == "*" a { print $1; exit }')
    if [[ ! "$sum" =~ ^[0-9a-f]{64}$ ]]; then
        echo "[!] No SHA-256 checksum for $asset in $repo's $sumfile; refusing to install it." >&2
        return 1
    fi
    gh_download_verified "$base/$asset" "sha256:$sum" "$dest"
}
