#!/usr/bin/env bash
# ==========================================
# Obsidian vault discovery helpers (sourced by obsidian-tui.sh, obsidian-sync.sh, obsidian-colorengine.sh)
# ==========================================
#   obsidian_vaults         prints known vault paths (one per line): open app vaults first,
#                           then other app vaults (~/.config/obsidian/obsidian.json), then the
#                           headless-linked vault (~/.config/obsidian-sync/vault), deduplicated.
#   obsidian_app_vaults     only the vaults the Obsidian app knows (open first); no headless vault.
#   obsidian_default_vault  prints the first vault from obsidian_vaults (returns 1 if none).

[ -n "${_DOTFILES_OBSIDIAN_LOADED:-}" ] && return 0
_DOTFILES_OBSIDIAN_LOADED=1

OBSIDIAN_APP_CONFIG="${OBSIDIAN_APP_CONFIG:-$HOME/.config/obsidian/obsidian.json}"
OBSIDIAN_SYNC_VAULT_FILE="${OBSIDIAN_SYNC_VAULT_FILE:-$HOME/.config/obsidian-sync/vault}"

obsidian_vaults() {
    {
        if [ -f "$OBSIDIAN_APP_CONFIG" ] && command -v jq >/dev/null 2>&1; then
            jq -r '([.vaults[]? | select(.open == true) | .path] + [.vaults[]? | select(.open != true) | .path])[]' \
                "$OBSIDIAN_APP_CONFIG" 2>/dev/null || true
        fi
        if [ -f "$OBSIDIAN_SYNC_VAULT_FILE" ]; then
            head -n 1 "$OBSIDIAN_SYNC_VAULT_FILE" 2>/dev/null || true
        fi
    } | awk 'NF && !seen[$0]++'
}

obsidian_app_vaults() {
    OBSIDIAN_SYNC_VAULT_FILE=/dev/null obsidian_vaults
}

obsidian_default_vault() {
    local v
    v=$(obsidian_vaults | head -n 1)
    [ -n "$v" ] || return 1
    printf '%s\n' "$v"
}
