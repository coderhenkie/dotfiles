#!/usr/bin/env bash

# ==========================================
# Debian 13 (Trixie) - i3 & Dotfiles Setup
# ==========================================

set -eu

echo "🚀 Start systeem configuratie..."

# ==========================================
# 1. Pakketbeheer optimaliseren met Nala
# ==========================================
echo "📦 Basis updaten en Nala installeren..."
sudo apt update
# Installeer nala en curl (nodig voor latere stappen)
sudo apt install -y nala curl

echo "🏎️ Snelste mirrors ophalen met Nala..."
# --auto kiest zelf de snelste mirrors, -y accepteert dit zonder vragen
sudo nala fetch --auto -y

echo "📦 Systeem upgraden via Nala..."
sudo nala upgrade -y

# ==========================================
# 2. Xorg, Display Manager & Applicaties
# ==========================================
echo "🖥️ Xorg en LightDM installeren..."
sudo nala install -y xserver-xorg xinit lightdm lightdm-gtk-greeter light-locker
sudo systemctl enable lightdm

echo "🪟 Applicaties installeren (inclusief FUSE voor AppImages)..."
sudo nala install -y i3 kitty polybar feh git rofi wget unzip fontconfig libfuse2 fuse picom

# ==========================================
# 3. Neovim (AppImage) Installeren
# ==========================================
echo "📝 Neovim installeren als AppImage..."
APPIMAGE_DIR="$HOME/appimages"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOCAL_BIN"

if [ ! -f "$APPIMAGE_DIR/nvim.appimage" ]; then
    echo "⬇️ Neovim downloaden..."
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
    
    # Maak uitvoerbaar en verplaats naar de appimages map
    chmod u+x nvim-linux-x86_64.appimage
    mv nvim-linux-x86_64.appimage "$APPIMAGE_DIR/nvim.appimage"
    
    # Maak een symlink in ~/.local/bin zodat je gewoon 'nvim' kunt typen
    ln -sf "$APPIMAGE_DIR/nvim.appimage" "$LOCAL_BIN/nvim"
    echo "✅ Neovim geïnstalleerd in $APPIMAGE_DIR en gelinkt naar $LOCAL_BIN"
else
    echo "✅ Neovim was al geïnstalleerd."
fi

# ==========================================
# 3.5 PATH configuratie voor ~/.local/bin
# ==========================================
echo "🔧 PATH controleren voor ~/.local/bin..."
if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "✅ ~/.local/bin toegevoegd aan ~/.bashrc"
else
    echo "✅ PATH was al correct ingesteld."
fi

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

# CRUCIALE FIX: Zorg dat de .config map bestaat vóórdat we gaan linken
mkdir -p "$CONFIG_DIR"

if [ ! -d "$DOTFILES_DIR" ]; then
    echo "🔧 Dotfiles clonen vanaf GitHub..."
    git clone https://github.com/coderhenkie/dotfiles.git "$DOTFILES_DIR"
fi

# De array met applicaties die we via dotfiles beheren
APPS=("i3" "kitty" "polybar" "feh" "rofi" "nvim" "picom")

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

# ==========================================
# 6. Rechten goedzetten
# ==========================================
echo "🔒 Uitvoerrechten instellen voor scripts..."

if [ -f "$DOTFILES_DIR/polybar/launch.sh" ]; then
    chmod +x "$DOTFILES_DIR/polybar/launch.sh"
    echo "✅ Polybar launch script uitvoerbaar gemaakt."
fi

echo "🎉 Setup voltooid!"
