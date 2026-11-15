#!/usr/bin/env bash
# ==========================================
# Give Claude Code and Antigravity CLI (agy) explicit access to the Obsidian vault
# ==========================================
#   ai-vault-access.sh [vault-path]     default: $OBSIDIAN_VAULT, else the vault the Obsidian app
#                                       last opened, else the one linked by `obsidian-sync setup`
#
# Merges allow rules into each tool's own settings file (both tools also write to these files,
# so they are merged with jq, not symlinked). The shared rules template ai/AGENTS.md is filled in
# with the vault path and written to ~/.config/ai/AGENTS.md (outside the repo, so the vault path
# never ends up on GitHub); that file is linked as both tools' global instructions.
# Safe to run again: nothing is duplicated. Re-run after editing ai/AGENTS.md.
#
# Claude Code : ~/.claude/settings.json  -> permissions.allow Read/Edit(/<vault>/**) (leading // = absolute path),
#               permissions.additionalDirectories <vault>;   ~/.claude/CLAUDE.md -> ~/.config/ai/AGENTS.md
# agy         : ~/.gemini/antigravity-cli/settings.json -> permissions.allow read_file/write_file(<vault>);
#               ~/.gemini/GEMINI.md -> ~/.config/ai/AGENTS.md
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/obsidian.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/obsidian.sh"

case "${1:-}" in -h|--help) help_from_header; exit 0 ;; esac

need jq

VAULT="${1:-${OBSIDIAN_VAULT:-}}"
[ -n "$VAULT" ] || VAULT=$(obsidian_default_vault) \
    || die "No vault found: pass the vault path, set OBSIDIAN_VAULT, or run 'obsidian-sync setup' first."
VAULT="${VAULT/#\~/$HOME}"
VAULT="${VAULT%/}"
TEMPLATE="$DOTFILES_DIR/ai/AGENTS.md"
RULES="${XDG_CONFIG_HOME:-$HOME/.config}/ai/AGENTS.md"

merge_json() { # file, jq filter (with $v = vault path)
    local file="$1" filter="$2" tmp
    mkdir -p "$(dirname "$file")"
    [ -s "$file" ] || echo '{}' > "$file"
    tmp=$(mktemp)
    if jq --arg v "$VAULT" "$filter" "$file" > "$tmp"; then
        cat "$tmp" > "$file"   # keep the file's inode and permissions
    else
        warn "$file is not valid JSON: left unchanged."
    fi
    rm -f "$tmp"
}

# shellcheck disable=SC2016  # $v and $xs are jq variables, not shell variables
add_unique='def add_unique($xs): ((. // []) + $xs) | unique;'

merge_json "$HOME/.claude/settings.json" "$add_unique
    .permissions.allow = (.permissions.allow | add_unique([\"Read(/\" + \$v + \"/**)\", \"Edit(/\" + \$v + \"/**)\"]))
  | .permissions.additionalDirectories = (.permissions.additionalDirectories | add_unique([\$v]))"

merge_json "$HOME/.gemini/antigravity-cli/settings.json" "$add_unique
    .permissions.allow = (.permissions.allow | add_unique([\"read_file(\" + \$v + \")\", \"write_file(\" + \$v + \")\"]))"

# Render the rules template (the vault path only exists in this local copy)
mkdir -p "$(dirname "$RULES")"
content=$(<"$TEMPLATE")
content="${content//"{{VAULT}}"/"$VAULT"}"
tmp=$(mktemp "$RULES.XXXXXX")
printf '%s\n' "$content" > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$RULES"

# Shared global instructions; an existing real file is never overwritten
for target in "$HOME/.claude/CLAUDE.md" "$HOME/.gemini/GEMINI.md"; do
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        warn "$target already exists: not replaced (add the vault rules from $RULES yourself)."
    else
        mkdir -p "$(dirname "$target")"
        ln -sfn "$RULES" "$target"
    fi
done

ok "Claude Code and agy may use the vault: $VAULT"
