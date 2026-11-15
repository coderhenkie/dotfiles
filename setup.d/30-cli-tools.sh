# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/30-cli-tools.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 4.5 Extra CLI Tools: Herdr & Antigravity CLI
# ==========================================
log "Configuring extra CLI tools..."

# Vendor install scripts: downloaded to a temp file and checked before they run (lib/bootstrap.sh).
# Both tools update themselves, so the installer only runs when the tool is missing.
# --- Herdr ---
if have herdr || [ -x "$LOCAL_BIN/herdr" ]; then
    ok "Herdr is already installed (it updates itself)."
else
    info "Installing Herdr..."
    if install_script "Herdr" https://herdr.dev/install.sh sh; then
        ok "Herdr installed."
    else
        warn "Herdr could not be installed (continuing setup)."
    fi
fi

# --- Antigravity CLI ---
if have agy || [ -x "$LOCAL_BIN/agy" ]; then
    ok "Antigravity CLI is already installed (it updates itself)."
else
    info "Installing Antigravity CLI..."
    if install_script "Antigravity CLI" https://antigravity.google/cli/install.sh bash; then
        ok "Antigravity CLI installed."
    else
        warn "Antigravity CLI could not be installed (continuing setup)."
    fi
fi

# --- Spicetify (Spotify theming for the Color Engine) ---
SPICETIFY_CURRENT=""
[ -x "$HOME/.spicetify/spicetify" ] && SPICETIFY_CURRENT=$("$HOME/.spicetify/spicetify" -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)
SPICETIFY_RC=0
gh_check_update "spicetify/cli" '^spicetify-[0-9.]+-linux-amd64\.tar\.gz$' "$SPICETIFY_CURRENT" || SPICETIFY_RC=$?
if [ "$SPICETIFY_RC" -eq 0 ]; then
    info "Installing Spicetify $GH_LATEST_VERSION (installed: ${SPICETIFY_CURRENT:-none})..."
    SPICETIFY_TMP=$(mktemp -d)
    TMP_PATHS+=("$SPICETIFY_TMP")
    SPICETIFY_TGZ="$SPICETIFY_TMP/spicetify.tar.gz"
    # Themes & config live in ~/.config/spicetify, so replacing the program files is safe
    if gh_download_verified "$GH_URL" "$GH_DIGEST" "$SPICETIFY_TGZ" \
        && mkdir -p "$HOME/.spicetify" \
        && tar -xzf "$SPICETIFY_TGZ" -C "$HOME/.spicetify" \
        && chmod +x "$HOME/.spicetify/spicetify"; then
        ok "Spicetify $GH_LATEST_VERSION installed."
    else
        warn "Spicetify could not be installed/updated (continuing setup)."
    fi
    rm -rf "$SPICETIFY_TMP"
elif [ "$SPICETIFY_RC" -eq 1 ]; then
    ok "Spicetify is up to date ($SPICETIFY_CURRENT)."
else
    warn "Could not check for Spicetify updates (offline or GitHub API limit)."
fi
[ -x "$HOME/.spicetify/spicetify" ] && ln -sfn "$HOME/.spicetify/spicetify" "$LOCAL_BIN/spicetify"

# Spicetify requires Spotify's prefs file, which only exists after Spotify's first launch
mkdir -p "$HOME/.config/spotify"
[ -f "$HOME/.config/spotify/prefs" ] || touch "$HOME/.config/spotify/prefs"

# --- Starship prompt + terminal CLI tools (Debian packages; colored by the Color Engine) ---
# starship: prompt (starship/init.bash)   fzf: fuzzy finder   ripgrep: fast grep (rg)
# fd-find: fast find   bat: cat with syntax highlighting   zoxide: jump to frequent folders (z)
info "Installing Starship prompt and CLI tools (fzf, ripgrep, fd, bat, zoxide)..."
sudo nala install -y starship fzf ripgrep fd-find bat zoxide
# LazyVim (nvim/): build-essential compiles Treesitter parsers, lazygit is the git UI behind <space>gg
sudo nala install -y build-essential lazygit

# Node.js LTS in ~/.local/opt/node (Debian's Node 20 is too old for Obsidian Headless; Mason uses it too)
bash "$DOTFILES_DIR/scripts/install-node.sh" || warn "Node.js could not be installed (continuing setup)."
# Obsidian Headless (`ob`): Sync without the app, run by scripts/obsidian-sync.sh. Link a vault once
# with `obsidian-sync.sh setup` (login is interactive, so setup.sh doesn't do it).
if [ -x "$LOCAL_BIN/npm" ]; then
    if "$LOCAL_BIN/npm" install -g --prefix "$HOME/.local" obsidian-headless >/dev/null 2>&1; then
        ok "Obsidian Headless installed/updated."
    else
        warn "Obsidian Headless could not be installed (continuing setup)."
    fi
fi
ln -sfn "$DOTFILES_DIR/scripts/obsidian-sync.sh" "$LOCAL_BIN/obsidian-sync"
# LevelDB binding for scripts/darkreader-theme.js (Dark Reader in Thorium follows the Color Engine)
if [ -x "$LOCAL_BIN/npm" ]; then
    "$LOCAL_BIN/npm" install --prefix "$HOME/.local/lib/dotfiles-node" classic-level >/dev/null 2>&1 \
        || warn "classic-level could not be installed (Dark Reader colors won't follow the theme)."
fi
# Debian ships fd and bat as fdfind and batcat (name clashes with other packages)
ln -sfn /usr/bin/fdfind "$LOCAL_BIN/fd"
ln -sfn /usr/bin/batcat "$LOCAL_BIN/bat"
ok "Starship and CLI tools installed."

# --- Claude Code ---
# The installer always downloads the full ~200MB binary, even when it is already current.
# Ask the release server for the latest version number first (tiny request) and skip if it matches.
CLAUDE_LATEST=$(curl -fsSL --max-time 10 https://downloads.claude.ai/claude-code-releases/latest 2>/dev/null || true)
CLAUDE_CURRENT=$("$LOCAL_BIN/claude" --version 2>/dev/null | awk '{print $1}' || true)
if [ -n "$CLAUDE_CURRENT" ] && [ "$CLAUDE_CURRENT" = "$CLAUDE_LATEST" ]; then
    ok "Claude Code $CLAUDE_CURRENT is already the latest version: skipping install."
else
    info "Installing Claude Code${CLAUDE_LATEST:+ $CLAUDE_LATEST}${CLAUDE_CURRENT:+ (currently $CLAUDE_CURRENT)}..."
    if install_script "Claude Code" https://claude.ai/install.sh bash; then
        ok "Claude Code installed."
    else
        warn "Claude Code could not be installed (continuing setup)."
    fi
fi

# --- Obsidian vault access for Claude Code and agy (allow rules + shared rules file ai/AGENTS.md) ---
bash "$DOTFILES_DIR/scripts/ai-vault-access.sh" || warn "Vault access for AI tools not configured (continuing setup)."

# ==========================================
# 4.8 PATH configuration for ~/.local/bin
# ==========================================
log "Checking PATH for ~/.local/bin..."
# Look for the literal line written below (grepping the expanded $HOME never matched it,
# so every run appended another copy)
# shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    ok "Added ~/.local/bin to ~/.bashrc"
fi
# Remove the extra copies that older runs of this script added (keeps the first one)
# shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if [ "$(grep -cFx "$PATH_LINE" "$HOME/.bashrc")" -gt 1 ]; then
    BASHRC_TMP=$(mktemp)
    TMP_PATHS+=("$BASHRC_TMP")
    awk -v line="$PATH_LINE" '$0 == line { if (seen++) next } 1' "$HOME/.bashrc" > "$BASHRC_TMP"
    cat "$BASHRC_TMP" > "$HOME/.bashrc"
    rm -f "$BASHRC_TMP"
    ok "Removed duplicate ~/.local/bin PATH lines from ~/.bashrc"
fi

# Path written into ~/.bashrc: the literal $HOME/dotfiles for the default clone (unchanged from
# earlier runs, so existing lines are recognised), the absolute path for a clone elsewhere
if [ "$DOTFILES_DIR" = "$HOME/dotfiles" ]; then
    # shellcheck disable=SC2016  # written literally; expanded by bash when ~/.bashrc runs
    BASHRC_DOTFILES='$HOME/dotfiles' BASHRC_MATCH='dotfiles'
else
    BASHRC_DOTFILES="$DOTFILES_DIR" BASHRC_MATCH="$DOTFILES_DIR"
fi

# CLI tools (fzf key bindings, zoxide, bat/ripgrep config): logic lives in cli/init.bash
if ! grep -Fq "$BASHRC_MATCH/cli/init.bash" "$HOME/.bashrc"; then
    printf '\n# CLI tools: fzf, ripgrep, fd, bat, zoxide (added by dotfiles setup.sh)\n[ -f "%s/cli/init.bash" ] && . "%s/cli/init.bash"\n' \
        "$BASHRC_DOTFILES" "$BASHRC_DOTFILES" >> "$HOME/.bashrc"
    ok "Added the CLI tools to ~/.bashrc"
fi

# Starship prompt: one source line, the logic lives in the repo (starship/init.bash)
if ! grep -Fq "$BASHRC_MATCH/starship/init.bash" "$HOME/.bashrc"; then
    printf '\n# Starship prompt, colored by the Color Engine (added by dotfiles setup.sh)\n[ -f "%s/starship/init.bash" ] && . "%s/starship/init.bash"\n' \
        "$BASHRC_DOTFILES" "$BASHRC_DOTFILES" >> "$HOME/.bashrc"
    ok "Added the Starship prompt to ~/.bashrc"
fi

