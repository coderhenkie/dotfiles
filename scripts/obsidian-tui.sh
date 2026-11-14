#!/usr/bin/env bash
# `obsidian` in a terminal (~/.local/bin/obsidian): today's daily note in Neovim (LazyVim + obsidian.nvim).
#   obsidian           -> vault last open in the app (or the first one)
#   obsidian <vault>   -> that vault (folder name, e.g. `obsidian jkg`)
# The Obsidian app itself: `obsidian-app` or Rofi. Sync runs via obsidian-sync.sh (headless) while the app is closed.

CONFIG="$HOME/.config/obsidian/obsidian.json"   # vaults known to the app
LINKED="$HOME/.config/obsidian-sync/vault"       # vault linked by `obsidian-sync setup` (headless)

# All vault paths: the app's list first (last open one first), then the headless-linked vault
all_vaults() {
    [ -f "$CONFIG" ] && jq -r '([.vaults[] | select(.open == true) | .path] + [.vaults[] | select(.open != true) | .path])[]' "$CONFIG"
    [ -f "$LINKED" ] && head -n 1 "$LINKED"
}
mapfile -t VAULTS < <(all_vaults | awk 'NF && !seen[$0]++')
[ ${#VAULTS[@]} -gt 0 ] || { echo "No Obsidian vault on this machine yet: run 'obsidian-sync setup' (or open the app: obsidian-app)." >&2; exit 1; }

if [ -n "${1:-}" ]; then
    vault=""
    for v in "${VAULTS[@]}"; do [ "$(basename "$v")" = "$1" ] && { vault=$v; break; }; done
    [ -n "$vault" ] || { echo "No vault named '$1'. Vaults: $(printf '%s\n' "${VAULTS[@]}" | xargs -rd '\n' -n1 basename | paste -sd, -)" >&2; exit 1; }
else
    vault=${VAULTS[0]}
fi
[ -d "$vault" ] || { echo "Vault folder not found: $vault" >&2; exit 1; }

cd "$vault" && exec nvim +"Obsidian today"
