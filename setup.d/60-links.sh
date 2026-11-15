# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/60-links.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 7. Dotfiles Symlinks Setup
# ==========================================
log "Creating symlinks for configuration directories..."
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR"

APPS=("i3" "kitty" "polybar" "feh" "rofi" "nvim" "picom" "btop" "dunst" "zathura" "autorandr" "fontconfig")

for app in "${APPS[@]}"; do
    TARGET_DIR="$CONFIG_DIR/$app"
    SOURCE_DIR="$DOTFILES_DIR/$app"
    mkdir -p "$SOURCE_DIR"
    # Right link: nothing; wrong/dead link: replaced; real dir: moved to <dir>.bak.<epoch> (lib/bootstrap.sh)
    ensure_link "$SOURCE_DIR" "$TARGET_DIR"
done
# btop rewrites btop.conf, so only btop.conf.default is tracked: create the real one when missing
btop_conf_init

