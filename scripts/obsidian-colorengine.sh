#!/usr/bin/env bash
# ==========================================
# Install the ColorEngine plugin into Obsidian vaults
# ==========================================
# Copies ~/dotfiles/obsidian/colorengine into <vault>/.obsidian/plugins/colorengine for every vault
# Obsidian knows on this machine (~/.config/obsidian/obsidian.json), or only the vault given as $1,
# and enables it. Run once per vault (and again after changing the plugin source). Obsidian Sync
# then carries the plugin to other devices, where it stays inactive (no ~/.cache/theme/obsidian.css).
# Copied, not symlinked: Sync doesn't follow symlinks.

set -eu
SRC="$HOME/dotfiles/obsidian/colorengine"
CONFIG="$HOME/.config/obsidian/obsidian.json"

if [ $# -gt 0 ]; then
    VAULTS=("$1")
elif [ -f "$CONFIG" ]; then
    mapfile -t VAULTS < <(jq -r '.vaults[].path' "$CONFIG")
else
    echo "No vaults found: open your vault in Obsidian once, or pass its path." >&2
    exit 1
fi

running=false
pgrep -x obsidian >/dev/null && running=true

for vault in "${VAULTS[@]}"; do
    cfg="$vault/.obsidian"
    [ -d "$cfg" ] || { echo "[!] Skipping $vault (no .obsidian folder)"; continue; }
    mkdir -p "$cfg/plugins/colorengine"
    cp "$SRC/manifest.json" "$SRC/main.js" "$cfg/plugins/colorengine/"

    list="$cfg/community-plugins.json"
    if [ -f "$list" ] && jq -e 'index("colorengine")' "$list" >/dev/null; then
        echo "[OK] $vault: plugin updated (already enabled)"
    elif $running; then
        echo "[OK] $vault: plugin copied. Obsidian is running: enable it under Settings > Community plugins"
    else
        [ -f "$list" ] || echo '[]' > "$list"
        jq '. + ["colorengine"]' "$list" > "$list.tmp" && mv "$list.tmp" "$list"
        echo "[OK] $vault: plugin installed and enabled"
    fi
done
