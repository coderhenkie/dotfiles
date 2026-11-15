#!/usr/bin/env bash
# ==========================================
# Node.js LTS in ~/.local/opt/node (no sudo, checksum-verified)
# ==========================================
# Debian 13 ships Node 20; Obsidian Headless (obsidian-sync.sh) needs >= 22. Installs or updates to
# the newest release of the current LTS line from nodejs.org, verified against SHASUMS256.txt, and
# links node/npm/npx into ~/.local/bin (also used by LazyVim's Mason). Run by setup.sh.
#
# The SHA-256 check is an integrity check (corrupt or truncated download), not authentication:
# SHASUMS256.txt comes from the same HTTPS server. Verifying its GPG signature would need the
# Node.js release keys in a keyring, which this no-sudo installer deliberately does not manage.
#
# Usage: install-node.sh [-h|--help]
set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need curl jq tar sha256sum

case "$(uname -m)" in
    x86_64)  ARCH=x64 ;;
    aarch64) ARCH=arm64 ;;
    *)       die "Unsupported architecture for the Node.js binaries: $(uname -m)" ;;
esac

PREFIX="$HOME/.local/opt/node"
BIN="$HOME/.local/bin"
mkdir -p "$BIN" "$HOME/.local/opt"

latest=$(curl -fsSL --max-time 20 --retry 2 https://nodejs.org/dist/index.json \
    | jq -r '[.[] | select(.lts != false)][0].version') || latest=""
if [[ ! "$latest" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "Could not look up the Node.js LTS version."
fi

current=$("$PREFIX/bin/node" --version 2>/dev/null || true)
if [ "$current" = "$latest" ]; then
    ok "Node.js is up to date ($current)."
else
    info "Installing Node.js $latest (installed: ${current:-none})..."
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    file="node-$latest-linux-$ARCH.tar.xz"
    curl -fsSL --retry 2 --connect-timeout 20 --max-time 1800 -o "$tmp/$file" "https://nodejs.org/dist/$latest/$file"
    curl -fsSL --retry 2 --max-time 20 -o "$tmp/SHASUMS256.txt" "https://nodejs.org/dist/$latest/SHASUMS256.txt"
    (cd "$tmp" && grep " $file\$" SHASUMS256.txt | sha256sum -c --quiet -) \
        || die "Node.js checksum mismatch, not installed."
    tar -xJf "$tmp/$file" -C "$tmp"
    rm -rf "$PREFIX.new" && mv "$tmp/node-$latest-linux-$ARCH" "$PREFIX.new"
    rm -rf "$PREFIX" && mv "$PREFIX.new" "$PREFIX"
    ok "Node.js $latest installed."
fi

for b in node npm npx; do ln -sfn "$PREFIX/bin/$b" "$BIN/$b"; done
