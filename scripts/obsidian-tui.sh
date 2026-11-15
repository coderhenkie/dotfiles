#!/usr/bin/env bash
# ==========================================
# `obsidian` in a terminal (~/.local/bin/obsidian): today's daily note in Neovim (LazyVim + obsidian.nvim)
# ==========================================
#   obsidian           -> vault last open in the app (or the first one)
#   obsidian <vault>   -> that vault (folder name, e.g. `obsidian notes`)
# The Obsidian app itself: `obsidian-app` or Rofi. Sync runs via obsidian-sync.sh (headless) while the app is closed.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/obsidian.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/obsidian.sh"

case "${1:-}" in -h|--help) help_from_header; exit 0 ;; esac

mapfile -t VAULTS < <(obsidian_vaults)
[ ${#VAULTS[@]} -gt 0 ] || die "No Obsidian vault on this machine yet: run 'obsidian-sync setup' (or open the app: obsidian-app)."

if [ -n "${1:-}" ]; then
    vault=""
    for v in "${VAULTS[@]}"; do [ "$(basename "$v")" = "$1" ] && { vault=$v; break; }; done
    [ -n "$vault" ] || die "No vault named '$1'. Vaults: $(printf '%s\n' "${VAULTS[@]}" | xargs -rd '\n' -n1 basename | paste -sd, -)"
else
    vault=${VAULTS[0]}
fi
[ -d "$vault" ] || die "Vault folder not found: $vault"

cd "$vault" && exec nvim +"Obsidian today"
