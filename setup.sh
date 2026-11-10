#!/usr/bin/env bash

# ==========================================
# Debian 13 (Trixie) - i3 & Dotfiles Setup
# ==========================================

set -eu

echo "🚀 Start systeem configuratie..."

# ==========================================
# 1. Pakketbeheer & Basis (Nala, Git, Curl)
# ==========================================
echo "📦 Basis updaten en Nala/Git/JQ installeren..."
sudo apt update
sudo apt install -y nala curl git jq

echo "🏎️ Snelste mirrors ophalen met Nala..."
sudo nala fetch --auto -y

echo "📦 Systeem upgraden via Nala..."
sudo nala upgrade -y

# ==========================================
# 2. Meest Recente Dotfiles Ophalen
# ==========================================
echo "📁 Meest recente dotfiles downloaden..."
DOTFILES_DIR="$HOME/dotfiles"

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

echo "🪟 Applicaties installeren (inclusief Firefox ESR)..."
sudo nala install -y i3 kitty polybar feh rofi wget unzip fontconfig libfuse2 fuse picom psmisc qutebrowser fastfetch thunar btop firefox-esr

# ==========================================
# 4. AppImages: Neovim & Obsidian
# ==========================================
echo "📝 AppImages downloaden en configureren..."
APPIMAGE_DIR="$HOME/appimages"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOCAL_BIN"

# --- NEOVIM ---
if [ ! -f "$APPIMAGE_DIR/nvim.appimage" ]; then
    echo "⬇️ Neovim downloaden..."
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
    chmod u+x nvim-linux-x86_64.appimage
    mv nvim-linux-x86_64.appimage "$APPIMAGE_DIR/nvim.appimage"
    ln -sf "$APPIMAGE_DIR/nvim.appimage" "$LOCAL_BIN/nvim"
    echo "✅ Neovim geïnstalleerd."
else
    echo "✅ Neovim was al geïnstalleerd."
fi

# --- OBSIDIAN (LATEST, NO ARM64) ---
if [ ! -f "$APPIMAGE_DIR/obsidian.appimage" ]; then
    echo "⬇️ Laatste versie van Obsidian ophalen via GitHub API..."
    OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r '.assets[] | .browser_download_url' | grep '\.AppImage$' | grep -v 'arm64' | head -n 1)
    
    if [ -n "$OBSIDIAN_URL" ]; then
        curl -LO "$OBSIDIAN_URL"
        OBS_APPIMAGE=$(basename "$OBSIDIAN_URL")
        chmod u+x "$OBS_APPIMAGE"
        mv "$OBS_APPIMAGE" "$APPIMAGE_DIR/obsidian.appimage"
        ln -sf "$APPIMAGE_DIR/obsidian.appimage" "$LOCAL_BIN/obsidian"
        
        # Maak de .desktop file voor Rofi (met --no-sandbox vlag)
        mkdir -p "$HOME/.local/share/applications"
        cat <<EOF > "$HOME/.local/share/applications/obsidian.desktop"
[Desktop Entry]
Name=Obsidian
Exec=$HOME/.local/bin/obsidian --no-sandbox %U
Terminal=false
Type=Application
Icon=obsidian
StartupWMClass=obsidian
Comment=Obsidian Markdown Note-taking
Categories=Office;
EOF
        echo "✅ Obsidian succesvol geïnstalleerd en aan Rofi toegevoegd."
    else
        echo "⚠️ Kon Obsidian download URL niet vinden."
    fi
else
    echo "✅ Obsidian was al geïnstalleerd."
fi

# ==========================================
# 4.5 PATH configuratie voor ~/.local/bin
# ==========================================
echo "🔧 PATH controleren voor ~/.local/bin..."
if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "✅ ~/.local/bin toegevoegd aan ~/.bashrc"
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
fi

# ==========================================
# 6. Pywal (AI Color Engine) Installeren
# ==========================================
echo "🎨 Pywal en Python dependencies installeren..."
sudo nala install -y python3-pip python3-venv imagemagick

echo "🐍 Virtuele omgeving voor Pywal aanmaken in ~/.local/pywal-venv..."
python3 -m venv "$HOME/.local/pywal-venv"
"$HOME/.local/pywal-venv/bin/pip" install pywal
ln -sf "$HOME/.local/pywal-venv/bin/wal" "$LOCAL_BIN/wal"

# ==========================================
# 7. Dotfiles & Firefox Setup
# ==========================================
echo "📁 Symlinks aanmaken voor de configuratiebestanden..."
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR"

APPS=("i3" "kitty" "polybar" "feh" "rofi" "nvim" "picom" "qutebrowser")

for app in "${APPS[@]}"; do
    TARGET_DIR="$CONFIG_DIR/$app"
    SOURCE_DIR="$DOTFILES_DIR/$app"
    mkdir -p "$SOURCE_DIR"

    if [ ! -L "$TARGET_DIR" ]; then
        if [ -e "$TARGET_DIR" ]; then
            mv "$TARGET_DIR" "${TARGET_DIR}.bak"
        fi
        ln -s "$SOURCE_DIR" "$TARGET_DIR"
    fi
done

echo "🦊 Firefox Ricing Profiel controleren..."
FF_DIR="$HOME/.mozilla/firefox"
FF_PROFILE="rice.default"

# FIX: Maak het rice profiel ALLEEN aan als het nog niet bestaat.
# Dit voorkomt dat je bij het herhaaldelijk draaien van setup.sh je Firefox profiel overschrijft.
if [ ! -d "$FF_DIR/$FF_PROFILE" ]; then
    echo "⚠️ Nieuw Firefox rice-profiel aanmaken..."
    mkdir -p "$FF_DIR/$FF_PROFILE/chrome"

    cat <<EOF > "$FF_DIR/profiles.ini"
[Profile0]
Name=default
IsRelative=1
Path=$FF_PROFILE
Default=1

[General]
StartWithLastProfile=1
Version=2
EOF

    cat <<EOF > "$FF_DIR/$FF_PROFILE/user.js"
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);
EOF
else
    echo "✅ Firefox rice-profiel bestaat al. (We raken je profiel niet aan!)"
    # Zorg wel dat de chrome map bestaat voor de CSS link
    mkdir -p "$FF_DIR/$FF_PROFILE/chrome"
fi

# ==========================================
# 8. Color Engine Bootstrap (Inclusief Firefox)
# ==========================================
echo "🎨 Standaard thema (bootstrap) genereren in ~/.cache/theme..."
CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

BG="#282a36"
FG="#f8f8f2"
ACCENT="#bd93f9"

cat <<EOF > "$CACHE_DIR/polybar.ini"
[colors]
background = $BG
foreground = $FG
primary = $ACCENT
EOF

cat <<EOF > "$CACHE_DIR/kitty.conf"
background $BG
foreground $FG
cursor $ACCENT
selection_background $ACCENT
color2 $ACCENT
EOF

cat <<EOF > "$CACHE_DIR/i3.conf"
set \$bg $BG
set \$fg $FG
set \$accent $ACCENT
client.focused \$accent \$accent \$bg \$accent \$accent
EOF

cat <<EOF > "$CACHE_DIR/rofi.rasi"
* {
    bg: $BG;
    fg: $FG;
    accent: $ACCENT;
    background-color: @bg;
    text-color: @fg;
}
EOF

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

# GTK3 (Thunar & GUI apps)
mkdir -p "$HOME/.config/gtk-3.0"
cat <<EOF > "$HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-application-prefer-dark-theme=1
EOF

cat <<EOF > "$CACHE_DIR/gtk.css"
@define-color theme_bg_color $BG;
@define-color theme_fg_color $FG;
@define-color theme_base_color $BG;
@define-color theme_text_color $FG;
@define-color theme_selected_bg_color $ACCENT;
@define-color theme_selected_fg_color $BG;
@define-color theme_unfocused_bg_color $BG;
@define-color theme_unfocused_text_color $FG;
EOF
ln -sf "$CACHE_DIR/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

# FIREFOX RICE (userChrome.css)
cat <<EOF > "$CACHE_DIR/userChrome.css"
/* Firefox Color Engine Rice */
:root {
  --bg-color: $BG !important;
  --fg-color: $FG !important;
  --accent-color: $ACCENT !important;
  --toolbar-bgcolor: $BG !important;
  --toolbar-color: $FG !important;
  --lwt-accent-color: $BG !important;
  --lwt-text-color: $FG !important;
  --tab-selected-bgcolor: $ACCENT !important;
  --tab-selected-textcolor: $BG !important;
}

#navigator-toolbox {
    background-color: var(--bg-color) !important;
    border: none !important;
}

#urlbar-background {
    background-color: var(--bg-color) !important;
    border: 1px solid var(--accent-color) !important;
}

.tab-background {
    background-color: var(--bg-color) !important;
    color: var(--fg-color) !important;
}

.tab-background[selected="true"] {
    background-color: var(--accent-color) !important;
}
EOF

ln -sf "$CACHE_DIR/userChrome.css" "$FF_DIR/$FF_PROFILE/chrome/userChrome.css"

echo "✅ Bootstrap thema gegenereerd."

# ==========================================
# 9. Rechten goedzetten
# ==========================================
echo "🔒 Uitvoerrechten instellen voor scripts..."

if [ -f "$DOTFILES_DIR/polybar/launch.sh" ]; then
    chmod +x "$DOTFILES_DIR/polybar/launch.sh"
    echo "✅ Polybar launch script uitvoerbaar gemaakt."
fi

if [ -f "$DOTFILES_DIR/scripts/theme-selector.sh" ]; then
    chmod +x "$DOTFILES_DIR/scripts/theme-selector.sh"
    echo "✅ Theme-selector script uitvoerbaar gemaakt."
fi

if [ -f "$DOTFILES_DIR/scripts/ai-theme.sh" ]; then
    chmod +x "$DOTFILES_DIR/scripts/ai-theme.sh"
    echo "✅ AI-theme script uitvoerbaar gemaakt."
fi

echo "🎉 Setup voltooid!"
