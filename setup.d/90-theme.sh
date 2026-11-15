# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/90-theme.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 9. Color Engine Bootstrap & Live Reload (Including LightDM, Thorium, Neovim, Herdr, btop & Spotify)
# ==========================================
log "Generating theme files in ~/.cache/theme..."
CACHE_DIR="$THEME_CACHE"
mkdir -p "$CACHE_DIR"

# Re-runs keep the active palette (theme selector / AI theme); Dracula only on a fresh install.
# Read as data (lib/common.sh theme_load), never sourced.
# shellcheck disable=SC2119  # theme_load without a file = the active theme
theme_load || theme_load "$DOTFILES_DIR/themes/dracula.theme" || die "No valid Color Engine theme found."
# shellcheck disable=SC2154  # bg/fg/accent are set by theme_load
BG="$bg" FG="$fg" ACCENT="$accent"

# herdr config, btop theme and ~/.local/bin/lock links (lib/bootstrap.sh; apply-theme.sh repeats it)
theme_runtime_links

# UI scale snippets for Rofi & Polybar (keeps the saved scale; 100% on a fresh install)
try "UI scale snippets" bash "$DOTFILES_DIR/scripts/ui-scale.sh" files

# Generate all theme files, ColorEngine icons, and live-reload i3 if a session is active
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$BG" "$FG" "$ACCENT"

ok "Bootstrap theme generated and applied."

# LazyVim: install the plugins pinned in nvim/lazy-lock.json (Mason tools follow on first start)
log "Installing Neovim plugins (LazyVim)..."
if "$LOCAL_BIN/nvim" --headless "+Lazy! restore" +qa >/dev/null 2>&1; then
    ok "Neovim plugins installed."
else
    warn "Neovim plugins could not be installed now; they install on the first start of nvim."
fi
ok "Setup completed!"
