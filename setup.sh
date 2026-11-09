#!/usr/bin/env bash

# ==========================================
# Debian 13 (Trixie) - i3 & Dotfiles Setup
# ==========================================

set -eu

echo "🚀 Start systeem configuratie..."

# ==========================================
# 1. Pakketbeheer & Basis (Nala, Git, Curl)
# ==========================================
echo "📦 Basis updaten en Nala/Git installeren..."
sudo apt update
# We installeren git hier al, zodat we direct de dotfiles kunnen ophalen
sudo apt install -y nala curl git

echo "🏎️ Snelste mirrors ophalen met Nala..."
# --auto kiest zelf de snelste mirrors, -y accepteert dit zonder vragen
sudo nala fetch --auto -y

echo "📦 Systeem upgraden via Nala..."
sudo nala upgrade -y

# ==========================================
# 2. Meest Recente Dotfiles Ophalen
# ==========================================
echo "📁 Meest recente dotfiles downloaden..."
DOTFILES_DIR="$HOME/dotfiles"

# Haal altijd de nieuwste versie op, of clone als de map niet bestaat
if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "🔄 Dotfiles map bestaat al. Updaten naar de nieuwste versie (git pull)..."
    git -C "$DOTFILES_DIR" pull
else
    echo "🔧 Dotfiles clonen vanaf GitHub..."
    git clone https://github.com/coderhenkie/dotfiles.git "$DOTFILES_DIR"
fi

# ==========================================
# 3. Xorg, Display Manager & Applicaties
# ==========================================
echo "🖥️ Xorg en LightDM installeren..."
sudo nala install -y xserver-xorg xinit lightdm lightdm-gtk-greeter light-locker
sudo systemctl enable lightdm

echo "🪟 Applicaties installeren (inclusief FUSE voor AppImages)..."
sudo nala install -y i3 kitty polybar feh rofi wget unzip fontconfig libfuse2 fuse picom psmisc qutebrowser

# ==========================================
# 4. Neovim (AppImage) Installeren
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
# 4.5 PATH configuratie voor ~/.local/bin
# ==========================================
echo "🔧 PATH controleren voor ~/.local/bin..."
if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "✅ ~/.local/bin toegevoegd aan ~/.bashrc"
else
    echo "✅ PATH was al correct ingesteld."
fi

# ==========================================
# 5. Nerd Fonts Installeren
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
# 6. Pywal (AI Color Engine) Installeren
# ==========================================
echo "🎨 Pywal en Python dependencies installeren..."
sudo nala install -y python3-pip python3-venv imagemagick

echo "🐍 Virtuele omgeving voor Pywal aanmaken in ~/.local/pywal-venv..."
python3 -m venv "$HOME/.local/pywal-venv"

echo "⬇️ Pywal installeren in de virtuele omgeving..."
"$HOME/.local/pywal-venv/bin/pip" install pywal

echo "🔗 Symlink maken voor Pywal (wal) in ~/.local/bin..."
ln -sf "$HOME/.local/pywal-venv/bin/wal" "$LOCAL_BIN/wal"
echo "✅ Pywal succesvol geïnstalleerd."

# ==========================================
# 7. Dotfiles Architectuur & Symlinks
# ==========================================
echo "📁 Symlinks aanmaken voor de configuratiebestanden..."
CONFIG_DIR="$HOME/.config"

# Zorg dat de .config map bestaat vóórdat we gaan linken
mkdir -p "$CONFIG_DIR"

# De array met applicaties die we via dotfiles beheren
APPS=("i3" "kitty" "polybar" "feh" "rofi" "nvim" "picom" "qutebrowser")

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
# 8. Color Engine Bootstrap
# ==========================================
echo "🎨 Standaard thema (bootstrap) genereren in ~/.cache/theme..."
CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

# Kies standaardkleuren (Dracula-achtig) voor de eerste run
BG="#282a36"
FG="#f8f8f2"
ACCENT="#bd93f9"

# Polybar
cat <<EOF > "$CACHE_DIR/polybar.ini"
[colors]
background = $BG
foreground = $FG
primary = $ACCENT
EOF

# Kitty
cat <<EOF > "$CACHE_DIR/kitty.conf"
background $BG
foreground $FG
cursor $ACCENT
selection_background $ACCENT
color2 $ACCENT
EOF

# i3
cat <<EOF > "$CACHE_DIR/i3.conf"
set \$bg $BG
set \$fg $FG
set \$accent $ACCENT
client.focused \$accent \$accent \$bg \$accent \$accent
EOF

# Rofi
cat <<EOF > "$CACHE_DIR/rofi.rasi"
* {
    bg: $BG;
    fg: $FG;
    accent: $ACCENT;
    background-color: @bg;
    text-color: @fg;
}
EOF

# Qutebrowser
cat <<EOF > "$CACHE_DIR/qutebrowser.py"
c.colors.statusbar.normal.bg = "$BG"
c.colors.statusbar.normal.fg = "$FG"
c.colors.tabs.even.bg = "$BG"
c.colors.tabs.even.fg = "$FG"
c.colors.tabs.odd.bg = "$BG"
c.colors.tabs.odd.fg = "$FG"
c.colors.tabs.selected.even.bg = "$ACCENT"
c.colors.tabs.selected.even.fg = "$BG"
c.colors.tabs.selected.odd.bg = "$ACCENT"
c.colors.tabs.selected.odd.fg = "$BG"
EOF

echo "✅ Bootstrap thema gegenereerd."

# ==========================================
# 9. Rechten goedzetten
# ==========================================
echo "🔒 Uitvoerrechten instellen voor scripts..."

if [ -f "$DOTFILES_DIR/polybar/launch.sh" ]; then
    chmod +x "$DOTFILES_DIR/polybar/launch.sh"
    echo "✅ Polybar launch script uitvoerbaar gemaakt."
fi

# Maak het theme-selector script uitvoerbaar
if [ -f "$DOTFILES_DIR/scripts/theme-selector.sh" ]; then
    chmod +x "$DOTFILES_DIR/scripts/theme-selector.sh"
    echo "✅ Theme-selector script uitvoerbaar gemaakt."
fi

# Maak het ai-theme script uitvoerbaar
if [ -f "$DOTFILES_DIR/scripts/ai-theme.sh" ]; then
    chmod +x "$DOTFILES_DIR/scripts/ai-theme.sh"
    echo "✅ AI-theme script uitvoerbaar gemaakt."
fi

echo "🎉 Setup voltooid!"
