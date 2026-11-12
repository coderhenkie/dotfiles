#!/usr/bin/env bash

# ==========================================
# Debian 13 (Trixie) - i3 & Dotfiles Setup
# ==========================================

set -eu

DOTFILES_DIR="$HOME/dotfiles"

if [ "${DOTFILES_SETUP_RELOADED:-0}" != "1" ]; then
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
    # 2. Fetch Latest Dotfiles & Re-exec Latest Setup Script
    # ==========================================
    echo "==> Fetching latest dotfiles..."

    if [ -d "$DOTFILES_DIR/.git" ]; then
        echo "==> Dotfiles directory already exists. Syncing with latest origin/main..."
        git -C "$DOTFILES_DIR" fetch origin
        git -C "$DOTFILES_DIR" reset --hard origin/main
    else
        echo "==> Cloning dotfiles from GitHub..."
        git clone https://github.com/coderhenkie/dotfiles.git "$DOTFILES_DIR"
    fi

    echo "==> Restarting setup using the latest version of $DOTFILES_DIR/setup.sh..."
    chmod +x "$DOTFILES_DIR/setup.sh"
    export DOTFILES_SETUP_RELOADED=1
    exec bash "$DOTFILES_DIR/setup.sh" "$@"
fi

# ==========================================
# 3. Xorg, Display Manager & Applications
# ==========================================
echo "==> Installing Xorg and LightDM..."
sudo nala install -y xserver-xorg xinit lightdm lightdm-gtk-greeter light-locker
sudo systemctl enable lightdm

echo "==> Installing audio stack (PipeWire + WirePlumber, Pulse/ALSA compatibility, SOF firmware)..."
sudo nala install -y pipewire pipewire-pulse pipewire-alsa wireplumber pulseaudio-utils alsa-utils pavucontrol firmware-sof-signed
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

echo "==> Installing applications & CLI tools (including JQ and NPM)..."
sudo nala install -y i3 kitty polybar feh rofi wget unzip fontconfig libfuse2 fuse picom psmisc fastfetch thunar btop jq npm playerctl

# --- SPOTIFY (official apt repo; installs /usr/share/applications/spotify.desktop so it shows up in Rofi) ---
echo "==> Installing Spotify from the official repository..."
sudo nala install -y gpg ca-certificates
# Spotify rotates its signing key periodically: read the current key ID from the repo signature,
# falling back to the last known one.
SPOTIFY_KEY_ID=$(curl -fsSL https://repository.spotify.com/dists/stable/Release.gpg \
    | gpg --list-packets 2>/dev/null | grep -oE 'keyid [0-9A-F]{16}' | head -n 1 | cut -d' ' -f2 || true)
SPOTIFY_KEY_ID="${SPOTIFY_KEY_ID:-5384CE82BA52C83A}"
sudo install -d -m 0755 /etc/apt/keyrings
if curl -fsSL "https://download.spotify.com/debian/pubkey_${SPOTIFY_KEY_ID}.gpg" \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/spotify.gpg; then
    echo "deb [signed-by=/etc/apt/keyrings/spotify.gpg] https://repository.spotify.com stable non-free" \
        | sudo tee /etc/apt/sources.list.d/spotify.list >/dev/null
    if sudo apt update && sudo nala install -y spotify-client; then
        # Spicetify needs write access to Spotify's app files to inject the Color Engine theme
        sudo chmod a+wr /usr/share/spotify
        sudo chmod -R a+wr /usr/share/spotify/Apps
        # The package's postinst doesn't reliably register its launcher, so link it for Rofi ourselves
        mkdir -p "$HOME/.local/share/applications"
        ln -sf /usr/share/spotify/spotify.desktop "$HOME/.local/share/applications/spotify.desktop"
        echo "[OK] Spotify installed."
    else
        echo "[!] Spotify install failed (continuing setup)."
        sudo rm -f /etc/apt/sources.list.d/spotify.list
    fi
else
    echo "[!] Could not fetch Spotify signing key (continuing setup)."
fi

# ==========================================
# 4. AppImages: Neovim, Obsidian & Thorium Browser
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

# --- THORIUM BROWSER (LATEST AVX2 / SSE4 APPIMAGE + EXTENSIONS + GTK THEME) ---
if [ ! -f "$APPIMAGE_DIR/thorium.appimage" ]; then
    echo " -> Fetching latest Thorium Browser release via GitHub API..."
    if grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
        THORIUM_ISA="AVX2"
    else
        THORIUM_ISA="SSE4"
    fi

    THORIUM_URL=$(curl -s "https://api.github.com/repos/Alex313031/Thorium/releases?per_page=15" | jq -r '[.[] | select((.assets | length) > 0)][0].assets[] | .browser_download_url' | grep '\.AppImage$' | grep "_${THORIUM_ISA}\." | head -n 1)

    if [ -n "$THORIUM_URL" ]; then
        curl -L -o "$APPIMAGE_DIR/thorium.appimage" "$THORIUM_URL"
        chmod u+x "$APPIMAGE_DIR/thorium.appimage"
        ln -sf "$APPIMAGE_DIR/thorium.appimage" "$LOCAL_BIN/thorium"
        echo "[OK] Thorium Browser ($THORIUM_ISA) installed."
    else
        echo "[!] Could not find Thorium Browser download URL."
    fi
else
    echo "[OK] Thorium Browser is already installed."
    ln -sf "$APPIMAGE_DIR/thorium.appimage" "$LOCAL_BIN/thorium"
fi

# Create the .desktop entry for Thorium in Rofi
mkdir -p "$HOME/.local/share/applications"
cat <<EOF > "$HOME/.local/share/applications/thorium.desktop"
[Desktop Entry]
Name=Thorium Browser
GenericName=Web Browser
Exec=$HOME/.local/bin/thorium --no-sandbox --no-default-browser-check %U
Terminal=false
Type=Application
Icon=thorium
StartupWMClass=thorium
Comment=Thorium High-Performance Web Browser
Categories=Network;WebBrowser;
EOF

# Configure automatic installation of latest Chrome Web Store extensions for Thorium:
# 1. Thorium Material Dark Theme (dahfohiipmpcppjbablgfoggbogdmddp)
# 2. Bitwarden Password Manager  (nngceckbapebfimnlniiiahkandclblb)
# 3. Ghostery Tracker/Ad Blocker (mlomiejdfkolichcflejclcbmpeaniij)
# 4. Vimium Keyboard Navigation  (dbepggeogbaibhgnhhndojpepiihcmeb)
THORIUM_EXT_IDS=(
    "dahfohiipmpcppjbablgfoggbogdmddp"
    "nngceckbapebfimnlniiiahkandclblb"
    "mlomiejdfkolichcflejclcbmpeaniij"
    "dbepggeogbaibhgnhhndojpepiihcmeb"
)

sudo mkdir -p /etc/chromium/policies/managed /etc/opt/chrome/policies/managed
sudo tee /etc/chromium/policies/managed/thorium_extensions.json /etc/opt/chrome/policies/managed/thorium_extensions.json >/dev/null <<EOF
{
  "ExtensionInstallForcelist": [
    "dahfohiipmpcppjbablgfoggbogdmddp;https://clients2.google.com/service/update2/crx",
    "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx",
    "mlomiejdfkolichcflejclcbmpeaniij;https://clients2.google.com/service/update2/crx",
    "dbepggeogbaibhgnhhndojpepiihcmeb;https://clients2.google.com/service/update2/crx"
  ]
}
EOF

mkdir -p "$HOME/.config/thorium/External Extensions"
for ext_id in "${THORIUM_EXT_IDS[@]}"; do
    cat <<EOF > "$HOME/.config/thorium/External Extensions/${ext_id}.json"
{
  "external_update_url": "https://clients2.google.com/service/update2/crx"
}
EOF
done

# Bootstrap Thorium Default Preferences to use GTK+ theme colors from the Color Engine
mkdir -p "$HOME/.config/thorium/Default"
if [ ! -f "$HOME/.config/thorium/Default/Preferences" ]; then
    cat <<EOF > "$HOME/.config/thorium/Default/Preferences"
{
  "browser": {
    "custom_chrome_frame": true,
    "theme": {
      "color_scheme2": 2
    }
  },
  "extensions": {
    "theme": {
      "id": "use_system",
      "system_theme": 1,
      "use_system": true
    }
  }
}
EOF
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

# --- Spicetify (Spotify theming for the Color Engine) ---
if [ ! -x "$HOME/.spicetify/spicetify" ]; then
    echo " -> Fetching latest Spicetify release via GitHub API..."
    SPICETIFY_URL=$(curl -s https://api.github.com/repos/spicetify/cli/releases/latest | jq -r '.assets[] | .browser_download_url' | grep 'linux-amd64\.tar\.gz$' | head -n 1)

    if [ -n "$SPICETIFY_URL" ]; then
        mkdir -p "$HOME/.spicetify"
        curl -fsSL "$SPICETIFY_URL" | tar -xz -C "$HOME/.spicetify"
        chmod +x "$HOME/.spicetify/spicetify"
        echo "[OK] Spicetify installed."
    else
        echo "[!] Could not find Spicetify download URL."
    fi
else
    echo "[OK] Spicetify is already installed."
fi
[ -x "$HOME/.spicetify/spicetify" ] && ln -sf "$HOME/.spicetify/spicetify" "$LOCAL_BIN/spicetify"

# Spicetify requires Spotify's prefs file, which only exists after Spotify's first launch
mkdir -p "$HOME/.config/spotify"
[ -f "$HOME/.config/spotify/prefs" ] || touch "$HOME/.config/spotify/prefs"

# --- Claude Code ---
echo " -> Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
echo "[OK] Claude Code installed."

# ==========================================
# 4.8 PATH configuration for ~/.local/bin
# ==========================================
echo "==> Checking PATH for ~/.local/bin..."
if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "[OK] Added ~/.local/bin to ~/.bashrc"
fi

# ==========================================
# 5. Install Nerd Fonts (User & System-wide for LightDM)
# ==========================================
echo "==> Installing JetBrainsMono Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
SYS_FONT_DIR="/usr/local/share/fonts/JetBrainsMono"

if [ ! -d "$FONT_DIR/JetBrainsMono" ]; then
    mkdir -p "$FONT_DIR/JetBrainsMono"
    wget -qO /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR/JetBrainsMono"
    rm /tmp/JetBrainsMono.zip
    fc-cache -fv
    echo "[OK] Font installed in ~/.local/share/fonts."
fi

if [ ! -d "$SYS_FONT_DIR" ]; then
    sudo mkdir -p "$SYS_FONT_DIR"
    sudo cp -rf "$FONT_DIR/JetBrainsMono/"* "$SYS_FONT_DIR/"
    sudo chmod -R a+rX "$SYS_FONT_DIR"
    sudo fc-cache -fv
    echo "[OK] Font installed system-wide for LightDM."
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
# 7. Dotfiles Symlinks Setup
# ==========================================
echo "==> Creating symlinks for configuration directories..."
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR"

APPS=("i3" "kitty" "polybar" "feh" "rofi" "nvim" "picom" "btop")

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

# Initialize local i3 hotkeys.conf from hotkeys.default only on first install
if [ ! -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && [ -f "$DOTFILES_DIR/i3/hotkeys.default" ]; then
    cp "$DOTFILES_DIR/i3/hotkeys.default" "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Initialized i3/hotkeys.conf from hotkeys.default."
elif [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/lock.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/hotkey-menu\.sh/a bindsym $mod+Shift+x exec --no-startup-id ~/dotfiles/scripts/lock.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added screen lock hotkey (\$mod+Shift+x) to existing i3/hotkeys.conf."
fi

# ==========================================
# 8. Set Executable Permissions & Screen Lock CLI
# ==========================================
echo "==> Setting executable permissions on scripts..."

if [ -f "$DOTFILES_DIR/polybar/launch.sh" ]; then
    chmod +x "$DOTFILES_DIR/polybar/launch.sh"
fi

chmod +x "$DOTFILES_DIR/scripts/"*.sh
ln -sf "$DOTFILES_DIR/scripts/lock.sh" "$LOCAL_BIN/lock"

# ==========================================
# 8.5 LightDM & light-locker Color Engine Integration
# ==========================================
echo "==> Configuring LightDM GTK Greeter and light-locker for Color Engine..."
bash "$DOTFILES_DIR/scripts/lockscreen-setup.sh"

# ==========================================
# 9. Color Engine Bootstrap & Live Reload (Including LightDM, Thorium, Neovim, Herdr, btop & Spotify)
# ==========================================
echo "==> Generating default bootstrap theme in ~/.cache/theme..."
CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

BG="#282a36"
FG="#f8f8f2"
ACCENT="#bd93f9"

# HERDR config symlink (only link config.toml so live sockets/logs stay out of git)
mkdir -p "$HOME/.config/herdr"
ln -sf "$CACHE_DIR/herdr.toml" "$HOME/.config/herdr/config.toml"

# BTOP theme symlink
mkdir -p "$HOME/.config/btop/themes"
ln -sf "$CACHE_DIR/btop.theme" "$HOME/.config/btop/themes/color_engine.theme"

# Generate all theme files, ColorEngine icons, and live-reload i3 if a session is active
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$BG" "$FG" "$ACCENT"

echo "[OK] Bootstrap theme generated and applied."
echo "[OK] Setup completed!"
