#!/usr/bin/env bash
# ==========================================
# Node.js LTS in ~/.local/opt/node (no sudo, checksum-verified)
# ==========================================
# Debian 13 ships Node 20; Obsidian Headless (obsidian-sync.sh) needs >= 22. Installs or updates to
# the newest release of the current LTS line from nodejs.org, verified against SHASUMS256.txt, and
# links node/npm/npx into ~/.local/bin (also used by LazyVim's Mason). Run by setup.sh.
set -eu

PREFIX="$HOME/.local/opt/node"
BIN="$HOME/.local/bin"
mkdir -p "$BIN" "$HOME/.local/opt"

latest=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version')
[ -n "$latest" ] && [ "$latest" != null ] || { echo "[!] Could not look up the Node.js LTS version." >&2; exit 1; }

current=$("$PREFIX/bin/node" --version 2>/dev/null || true)
if [ "$current" = "$latest" ]; then
    echo "[OK] Node.js is up to date ($current)."
else
    echo " -> Installing Node.js $latest (installed: ${current:-none})..."
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    file="node-$latest-linux-x64.tar.xz"
    curl -fsSL -o "$tmp/$file" "https://nodejs.org/dist/$latest/$file"
    curl -fsSL -o "$tmp/SHASUMS256.txt" "https://nodejs.org/dist/$latest/SHASUMS256.txt"
    (cd "$tmp" && grep " $file\$" SHASUMS256.txt | sha256sum -c --quiet -) \
        || { echo "[!] Node.js checksum mismatch, not installed." >&2; exit 1; }
    tar -xJf "$tmp/$file" -C "$tmp"
    rm -rf "$PREFIX.new" && mv "$tmp/node-$latest-linux-x64" "$PREFIX.new"
    rm -rf "$PREFIX" && mv "$PREFIX.new" "$PREFIX"
    echo "[OK] Node.js $latest installed."
fi

for b in node npm npx; do ln -sf "$PREFIX/bin/$b" "$BIN/$b"; done
