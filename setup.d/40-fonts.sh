# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/40-fonts.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 5. Fonts (modules in <dotfiles>/fonts, picker: $mod+Shift+f)
# ==========================================
log "Installing fonts..."

# User-owned system font dir: the LightDM greeter can read it, the font picker writes it without sudo
sudo mkdir -p "$FONTS_SYSTEM_DIR"
sudo chown "$USER:$USER" "$FONTS_SYSTEM_DIR"
sudo chmod 755 "$FONTS_SYSTEM_DIR"

# Migrate older layouts (one dir per font in ~/.local/share/fonts + root-owned system copies)
if [ -d "$HOME/.local/share/fonts/Iosevka" ]; then
    mkdir -p "$FONTS_SYSTEM_DIR/iosevka"
    mv -f "$HOME/.local/share/fonts/Iosevka/"* "$FONTS_SYSTEM_DIR/iosevka/" 2>/dev/null || true
    rm -rf "$HOME/.local/share/fonts/Iosevka"
    chmod -R a+rX "$FONTS_SYSTEM_DIR/iosevka"
fi
rm -rf "$HOME/.local/share/fonts/JetBrainsMono"
sudo rm -rf /usr/local/share/fonts/JetBrainsMono /usr/local/share/fonts/Iosevka
fc-cache -f >/dev/null 2>&1 || true

# Install every font module, so the picker ($mod+Shift+f) switches instantly without downloading
mapfile -t FONT_IDS < <(font_ids)
for font_id in "${FONT_IDS[@]}"; do
    if font_is_installed "$font_id"; then
        ok "$FONT_NAME Nerd Font is installed."
    else
        font_install "$font_id" || warn "$font_id font could not be installed (continuing setup)."
    fi
done

