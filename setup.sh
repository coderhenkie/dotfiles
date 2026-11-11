#!/usr/bin/env bash

# ==========================================
# Debian 13 (Trixie) - i3 & Dotfiles Setup
# ==========================================

set -eu

echo "==> Starting system configuration..."

# ==========================================
# 1. Package Management & Base Tools (Nala, Git, Curl)
# ==========================================
echo "==> Updating base packages and installing Nala/Git..."
sudo apt update
sudo apt install -y nala curl git

echo "==> Fetching fastest mirrors with Nala..."
sudo nala fetch --auto -y

echo "==> Upgrading system via Nala..."
sudo nala upgrade -y

# ==========================================
# 2. Fetch Latest Dotfiles
# ==========================================
echo "==> Fetching latest dotfiles..."
DOTFILES_DIR="$HOME/dotfiles"

if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "==> Dotfiles directory already exists. Pulling latest version (git pull)..."
    git -C "$DOTFILES_DIR" pull
else
    echo "==> Cloning dotfiles from GitHub..."
    git clone https://github.com/coderhenkie/dotfiles.git "$DOTFILES_DIR"
fi

# ==========================================
# 3. Xorg, Display Manager & Applications
# ==========================================
echo "==> Installing Xorg and LightDM..."
sudo nala install -y xserver-xorg xinit lightdm lightdm-gtk-greeter light-locker
sudo systemctl enable lightdm

echo "==> Installing applications & CLI tools (including Firefox ESR, JQ, and NPM)..."
sudo nala install -y i3 kitty polybar feh rofi wget unzip fontconfig libfuse2 fuse picom psmisc qutebrowser fastfetch thunar btop firefox-esr jq npm

# ==========================================
# 4. AppImages: Neovim & Obsidian
# ==========================================
echo "==> Downloading and configuring AppImages..."
APPIMAGE_DIR="$HOME/appimages"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOCAL_BIN"

# --- NEOVIM ---
if [ ! -f "$APPIMAGE_DIR/nvim.appimage" ]; then
    echo " -> Downloading Neovim..."
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
    chmod u+x nvim-linux-x86_64.appimage
    mv nvim-linux-x86_64.appimage "$APPIMAGE_DIR/nvim.appimage"
    ln -sf "$APPIMAGE_DIR/nvim.appimage" "$LOCAL_BIN/nvim"
    echo "[OK] Neovim installed."
else
    echo "[OK] Neovim is already installed."
fi

# --- OBSIDIAN (LATEST, NO ARM64) ---
if [ ! -f "$APPIMAGE_DIR/obsidian.appimage" ]; then
    echo " -> Fetching latest Obsidian release via GitHub API..."
    OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r '.assets[] | .browser_download_url' | grep '\.AppImage$' | grep -v 'arm64' | head -n 1)

    if [ -n "$OBSIDIAN_URL" ]; then
        curl -LO "$OBSIDIAN_URL"
        OBS_APPIMAGE=$(basename "$OBSIDIAN_URL")
        chmod u+x "$OBS_APPIMAGE"
        mv "$OBS_APPIMAGE" "$APPIMAGE_DIR/obsidian.appimage"
        ln -sf "$APPIMAGE_DIR/obsidian.appimage" "$LOCAL_BIN/obsidian"

        # Create the .desktop entry for Rofi (with --no-sandbox flag)
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
        echo "[OK] Obsidian installed and added to Rofi."
    else
        echo "[!] Could not find Obsidian download URL."
    fi
else
    echo "[OK] Obsidian is already installed."
fi

# ==========================================
# 4.5 Extra CLI Tools: Herdr & Antigravity CLI
# ==========================================
echo "==> Configuring extra CLI tools..."

# --- Herdr ---
echo " -> Installing Herdr..."
curl -fsSL https://herdr.dev/install.sh | sh
echo "[OK] Herdr installed."

# --- Antigravity CLI ---
echo " -> Installing Antigravity CLI..."
curl -fsSL https://antigravity.google/cli/install.sh | bash
echo "[OK] Antigravity CLI installed."

# ==========================================
# 4.8 PATH configuration for ~/.local/bin
# ==========================================
echo "==> Checking PATH for ~/.local/bin..."
if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "[OK] Added ~/.local/bin to ~/.bashrc"
fi

# ==========================================
# 5. Install Nerd Fonts
# ==========================================
echo "==> Installing JetBrainsMono Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"

if [ ! -d "$FONT_DIR/JetBrainsMono" ]; then
    mkdir -p "$FONT_DIR/JetBrainsMono"
    wget -qO /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR/JetBrainsMono"
    rm /tmp/JetBrainsMono.zip
    fc-cache -fv
    echo "[OK] Font installed."
fi

# ==========================================
# 6. Install Pywal (AI Color Engine)
# ==========================================
echo "==> Installing Pywal and Python dependencies..."
sudo nala install -y python3-pip python3-venv imagemagick

echo "==> Creating virtual environment for Pywal in ~/.local/pywal-venv..."
python3 -m venv "$HOME/.local/pywal-venv"
"$HOME/.local/pywal-venv/bin/pip" install pywal
ln -sf "$HOME/.local/pywal-venv/bin/wal" "$LOCAL_BIN/wal"

# ==========================================
# 7. Dotfiles & Firefox Setup
# ==========================================
echo "==> Creating symlinks for configuration directories..."
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

echo "==> Checking Firefox ricing profile..."
FF_DIR="$HOME/.mozilla/firefox"
FF_PROFILE="rice.default"

if [ ! -d "$FF_DIR/$FF_PROFILE" ]; then
    echo " -> Creating new Firefox rice profile..."
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
    echo "[OK] Firefox rice profile already exists. (Leaving existing profile untouched!)"
    mkdir -p "$FF_DIR/$FF_PROFILE/chrome"
fi

# ==========================================
# 8. Color Engine Bootstrap (Including Firefox, Neovim & Herdr)
# ==========================================
echo "==> Generating default bootstrap theme in ~/.cache/theme..."
CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

BG="#282a36"
FG="#f8f8f2"
ACCENT="#bd93f9"

# Generate all theme files and the ColorEngine icon theme via the central Color Engine (without live reload)
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$BG" "$FG" "$ACCENT" --no-reload

# FIREFOX RICE symlink (userChrome.css)
ln -sf "$CACHE_DIR/userChrome.css" "$FF_DIR/$FF_PROFILE/chrome/userChrome.css"

# HERDR config symlink (only link config.toml so live sockets/logs stay out of git)
mkdir -p "$HOME/.config/herdr"
ln -sf "$CACHE_DIR/herdr.toml" "$HOME/.config/herdr/config.toml"

echo "[OK] Bootstrap theme generated."

# ==========================================
# 9. Set Executable Permissions
# ==========================================
echo "==> Setting executable permissions on scripts..."

if [ -f "$DOTFILES_DIR/polybar/launch.sh" ]; then
    chmod +x "$DOTFILES_DIR/polybar/launch.sh"
fi

chmod +x "$DOTFILES_DIR/scripts/"*.sh

echo "[OK] Setup completed!"
