#!/usr/bin/env bash
# ==========================================
# Give Claude Code and Antigravity CLI (agy) explicit access to the Obsidian vault
# ==========================================
# Merges allow rules into each tool's own settings file (both tools also write to these files,
# so they are merged with jq, not symlinked) and links the shared rules file
# ~/dotfiles/ai/AGENTS.md as their global instructions. Safe to run again: nothing is duplicated.
#
#   ai-vault-access.sh [vault-path]     default: $OBSIDIAN_VAULT, else ~/Documents/notes
#
# Claude Code : ~/.claude/settings.json  -> permissions.allow Read/Edit(/<vault>/**) (leading // = absolute path),
#               permissions.additionalDirectories <vault>;   ~/.claude/CLAUDE.md -> ai/AGENTS.md
# agy         : ~/.gemini/antigravity-cli/settings.json -> permissions.allow read_file/write_file(<vault>);
#               ~/.gemini/GEMINI.md -> ai/AGENTS.md
set -eu

DOTFILES_DIR="$HOME/dotfiles"
VAULT="${1:-${OBSIDIAN_VAULT:-$HOME/Documents/notes}}"
VAULT="${VAULT%/}"
RULES="$DOTFILES_DIR/ai/AGENTS.md"

command -v jq >/dev/null || { echo "[!] jq is missing: vault access for AI tools not configured." >&2; exit 1; }

merge_json() { # file, jq filter (with $v = vault path)
    local file="$1" filter="$2" tmp
    mkdir -p "$(dirname "$file")"
    [ -s "$file" ] || echo '{}' > "$file"
    tmp=$(mktemp)
    if jq --arg v "$VAULT" "$filter" "$file" > "$tmp"; then
        cat "$tmp" > "$file"   # keep the file's inode and permissions
    else
        echo "[!] $file is not valid JSON: left unchanged." >&2
    fi
    rm -f "$tmp"
}

add_unique='def add_unique($xs): ((. // []) + $xs) | unique;'

merge_json "$HOME/.claude/settings.json" "$add_unique
    .permissions.allow = (.permissions.allow | add_unique([\"Read(/\" + \$v + \"/**)\", \"Edit(/\" + \$v + \"/**)\"]))
  | .permissions.additionalDirectories = (.permissions.additionalDirectories | add_unique([\$v]))"

merge_json "$HOME/.gemini/antigravity-cli/settings.json" "$add_unique
    .permissions.allow = (.permissions.allow | add_unique([\"read_file(\" + \$v + \")\", \"write_file(\" + \$v + \")\"]))"

# Shared global instructions; an existing real file is never overwritten
for target in "$HOME/.claude/CLAUDE.md" "$HOME/.gemini/GEMINI.md"; do
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "[!] $target already exists: not replaced (add the vault rules from $RULES yourself)."
    else
        mkdir -p "$(dirname "$target")"
        ln -sfn "$RULES" "$target"
    fi
done

echo "[OK] Claude Code and agy may use the vault: $VAULT"
