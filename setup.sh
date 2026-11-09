#!/usr/bin/env bash

# ==========================================
# Debian 13 (Trixie) - i3 & Dotfiles Setup
# ==========================================

set -eu

echo "🚀 Start systeem configuratie..."

# 1. Repositories updaten
echo "📦 Repositories updaten..."
sudo apt update
sudo apt upgrade -y

# 2. Xorg en Display Manager installeren
echo "🖥️ Xorg en LightDM installeren..."
sudo apt install -y xserver-xorg xinit lightdm lightdm-gtk-greeter light-locker
sudo systemctl enable lightdm

# 3. Window Manager & Applicaties installeren

echo "🪟 Applicaties installeren..."
sudo apt install -y i3 kitty polybar feh git rofi wget unzip fontconfig

# ==========================================
# 4. Nerd Fonts Installeren
# ==========================================
echo "🔤 JetBrainsMono Nerd Font installeren..."
FONT_DIR="$HOME/.local/share/fonts"

if [ ! -d "$FONT_DIR/JetBrainsMono" ]; then
    mkdir -p "$FONT_DIR/JetBrainsMono"
    wget -qO /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR/JetBrainsMono"
    rm /tmp/JetBrainsMono.zip
    # Update de font cache van het systeem
    fc-cache -fv
    echo "✅ Font geïnstalleerd."
else
    echo "✅ Font was al geïnstalleerd."
fi

# ==========================================
# 5. Dotfiles Architectuur
# ==========================================
echo "📁 Dotfiles structuur voorbereiden..."

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

if [ ! -d "$DOTFILES_DIR" ]; then
    mkdir -p "$DOTFILES_DIR"
    echo "🔧 Git repository initialiseren..."
    git -C "$DOTFILES_DIR" init
fi

# Nieuw: rofi toegevoegd aan de array
APPS=("i3" "kitty" "polybar" "feh" "rofi")

for app in "${APPS[@]}"; do
    TARGET_DIR="$CONFIG_DIR/$app"
    SOURCE_DIR="$DOTFILES_DIR/$app"

    mkdir -p "$SOURCE_DIR"

    if [ -L "$TARGET_DIR" ] && [ "$(readlink "$TARGET_DIR")" = "$SOURCE_DIR" ]; then
        echo "✅ Symlink voor $app staat al goed."
    else
        if [ -e "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
            echo "⚠️ Backup maken naar ${TARGET_DIR}.bak..."
            mv "$TARGET_DIR" "${TARGET_DIR}.bak"
        fi
        
        echo "🔗 Symlink maken: $TARGET_DIR -> $SOURCE_DIR"
        ln -s "$SOURCE_DIR" "$TARGET_DIR"
    fi
done

echo "🎉 Setup voltooid!"
