#!/usr/bin/env bash
# ==========================================
# Install the ColorEngine plugin into Obsidian vaults
# ==========================================
# Copies <dotfiles>/obsidian/colorengine into <vault>/.obsidian/plugins/colorengine for every vault
# Obsidian knows on this machine (~/.config/obsidian/obsidian.json and ~/.config/obsidian-sync/vault),
# or only the vault given as $1, and enables it. Run once per vault (and again after changing the
# plugin source). Obsidian Sync then carries the plugin to other devices, where it stays inactive
# (no ~/.cache/theme/obsidian.css). Copied, not symlinked: Sync doesn't follow symlinks.
#
# Usage: obsidian-colorengine.sh [vault-path]

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/obsidian.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/obsidian.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need jq

SRC="$DOTFILES_DIR/obsidian/colorengine"

if [ $# -gt 0 ]; then
    VAULTS=("$1")
else
    mapfile -t VAULTS < <(obsidian_app_vaults)   # app vaults only, as before
    [ "${#VAULTS[@]}" -gt 0 ] || die "No vaults found: open your vault in Obsidian once, or pass its path."
fi

running=false
pgrep -x obsidian >/dev/null 2>&1 && running=true

for vault in "${VAULTS[@]}"; do
    cfg="$vault/.obsidian"
    [ -d "$cfg" ] || { warn "Skipping $vault (no .obsidian folder)"; continue; }
    mkdir -p "$cfg/plugins/colorengine"
    cp "$SRC/manifest.json" "$SRC/main.js" "$cfg/plugins/colorengine/"

    list="$cfg/community-plugins.json"
    if [ -f "$list" ] && jq -e 'index("colorengine")' "$list" >/dev/null; then
        ok "$vault: plugin updated (already enabled)"
    elif $running; then
        ok "$vault: plugin copied. Obsidian is running: enable it under Settings > Community plugins"
    else
        [ -f "$list" ] || echo '[]' > "$list"
        jq '. + ["colorengine"]' "$list" > "$list.tmp" && mv "$list.tmp" "$list"
        ok "$vault: plugin installed and enabled"
    fi
done
