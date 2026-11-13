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
sudo nala install -y i3 kitty polybar feh rofi wget unzip fontconfig libfuse2 fuse picom psmisc fastfetch thunar btop jq playerctl maim xclip xdg-user-dirs dunst libnotify-bin yad

# --- SPOTIFY (official apt repo; installs /usr/share/applications/spotify.desktop so it shows up in Rofi) ---
# ==========================================
# 3.5 Desktop Essentials
# ==========================================
echo "==> Installing desktop essentials (network, polkit, viewers, archives, Rofi tools, displays, backups)..."
# network-manager(-gnome): Wi-Fi/VPN + nm-applet tray icon   mate-polkit: GUI password prompts (pkexec)
# zathura/imv/mpv: PDF, image & media viewers               thunar-archive-plugin/xarchiver: "Extract here"
# gvfs-backends: phones (MTP), SMB/SFTP shares in Thunar     qalc/xdotool/unicode-data/noto emoji: Rofi tools
# autorandr/arandr: monitor profiles & layout GUI            timeshift: system snapshots
# earlyoom/zram-tools: low-memory protection
sudo nala install -y \
    network-manager network-manager-gnome mate-polkit \
    zathura zathura-pdf-poppler imv mpv \
    thunar-archive-plugin xarchiver gvfs-backends \
    qalc xdotool unicode-data fonts-noto-color-emoji \
    autorandr arandr timeshift \
    earlyoom zram-tools

# ukui-polkit gets pulled in as a polkit agent but only starts inside UKUI/MATE; mate-polkit replaces it
if dpkg -s ukui-polkit >/dev/null 2>&1; then
    sudo apt-get remove -y ukui-polkit
fi

# Compressed swap in RAM (zstd, up to 50% of RAM) so memory spikes don't hit the disk
printf 'ALGO=zstd\nPERCENT=50\nPRIORITY=100\n' | sudo tee /etc/default/zramswap >/dev/null
sudo systemctl enable zramswap >/dev/null 2>&1 || true
sudo systemctl restart zramswap || echo "[!] zramswap could not be started (continuing setup)."

# earlyoom: kill the biggest browser/Electron process before the whole desktop freezes.
# (No quotes inside EARLYOOM_ARGS: systemd splits it on spaces and passes quotes literally.)
echo 'EARLYOOM_ARGS="-r 3600 --prefer ^(thorium|chrome|obsidian|spotify)$ --avoid ^(init|systemd|Xorg|i3|polybar|lightdm|sshd|dunst|kitty)$"' \
    | sudo tee /etc/default/earlyoom >/dev/null
sudo systemctl enable earlyoom >/dev/null 2>&1 || true
sudo systemctl restart earlyoom || echo "[!] earlyoom could not be started (continuing setup)."

# --- Laptop only: battery power management (TLP) ---
if ls -d /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    echo "==> Battery detected: installing TLP power management..."
    sudo nala install -y tlp
    sudo systemctl enable --now tlp
else
    echo "[OK] No battery detected: skipping TLP."
fi

# --- Bluetooth only when the machine has a Bluetooth controller ---
# /sys/class/bluetooth lists loaded controllers; USB class e0/01/01 catches adapters without a loaded driver.
HAS_BLUETOOTH=0
[ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] && HAS_BLUETOOTH=1
for usb_if in /sys/bus/usb/devices/*:*; do
    [ "$(cat "$usb_if/bInterfaceClass" 2>/dev/null)$(cat "$usb_if/bInterfaceSubClass" 2>/dev/null)$(cat "$usb_if/bInterfaceProtocol" 2>/dev/null)" = "e00101" ] && HAS_BLUETOOTH=1
done
if [ "$HAS_BLUETOOTH" = 1 ]; then
    echo "==> Bluetooth controller detected: installing BlueZ + Blueman (tray applet starts at login)..."
    sudo nala install -y bluez blueman
    sudo systemctl enable --now bluetooth
else
    echo "[OK] No Bluetooth controller detected: skipping Bluetooth."
fi

# --- Bare metal only: firmware updates (BIOS, SSD, peripherals) via LVFS ---
if systemd-detect-virt -q; then
    echo "[OK] Virtual machine detected: skipping fwupd."
else
    echo "==> Bare metal detected: installing fwupd (run 'fwupdmgr get-updates' to check firmware)..."
    sudo nala install -y fwupd
fi

# NetworkManager leaves interfaces listed in /etc/network/interfaces to ifupdown, so a wired/SSH
# connection configured by the Debian installer keeps working. Wi-Fi configured there is NOT
# managed by nm-applet; it is never changed automatically because that could cut the connection.
if grep -qsE '^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+wl' /etc/network/interfaces /etc/network/interfaces.d/*; then
    echo "[!] Wi-Fi is configured in /etc/network/interfaces, so nm-applet cannot manage it."
    echo "    To hand it to NetworkManager: comment out the wl* lines there and reboot (do this locally, not over SSH)."
fi

echo "==> Enabling automatic security updates (unattended-upgrades)..."
sudo nala install -y unattended-upgrades
# Daily package list refresh + unattended upgrade run (Debian security & stable point releases)
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' \
    | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null

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
        # Spicetify needs write access to Spotify's app files to inject the Color Engine theme.
        # Give that access to the desktop user only (never world-writable: any process could swap the binary).
        sudo chown -R "$USER:$USER" /usr/share/spotify
        sudo chmod -R u+rwX,go+rX,go-w /usr/share/spotify
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

# Every GitHub download below is verified against GitHub's published SHA-256 checksum
# shellcheck source=scripts/lib/github-download.sh
source "$DOTFILES_DIR/scripts/lib/github-download.sh"

# --- NEOVIM (install, or update when a newer release exists) ---
NVIM_CURRENT=""
[ -x "$APPIMAGE_DIR/nvim.appimage" ] && NVIM_CURRENT=$("$APPIMAGE_DIR/nvim.appimage" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
if gh_check_update "neovim/neovim" '^nvim-linux-x86_64\.appimage$' "$NVIM_CURRENT"; then
    echo " -> Installing Neovim $GH_LATEST_VERSION (installed: ${NVIM_CURRENT:-none})..."
    if gh_download_verified "$GH_URL" "$GH_DIGEST" "$APPIMAGE_DIR/nvim.appimage"; then
        chmod u+x "$APPIMAGE_DIR/nvim.appimage"
        echo "[OK] Neovim $GH_LATEST_VERSION installed."
    else
        echo "[!] Neovim could not be installed/updated (continuing setup)."
    fi
elif [ $? -eq 1 ]; then
    echo "[OK] Neovim is up to date ($NVIM_CURRENT)."
else
    echo "[!] Could not check for Neovim updates (offline or GitHub API limit)."
fi
[ -x "$APPIMAGE_DIR/nvim.appimage" ] && ln -sf "$APPIMAGE_DIR/nvim.appimage" "$LOCAL_BIN/nvim"

# --- OBSIDIAN (LATEST, NO ARM64) ---
if [ ! -f "$APPIMAGE_DIR/obsidian.appimage" ]; then
    echo " -> Fetching latest Obsidian release (checksum-verified)..."
    if gh_install_latest "obsidianmd/obsidian-releases" '^Obsidian-[0-9.]+\.AppImage$' "$APPIMAGE_DIR/obsidian.appimage"; then
        chmod u+x "$APPIMAGE_DIR/obsidian.appimage"
        ln -sf "$APPIMAGE_DIR/obsidian.appimage" "$LOCAL_BIN/obsidian"
        echo "[OK] Obsidian installed."
    else
        echo "[!] Obsidian could not be installed (continuing setup)."
    fi
else
    echo "[OK] Obsidian is already installed."
fi

# Create the .desktop entry for Rofi. No --no-sandbox: Debian 13 allows unprivileged user
# namespaces, so Electron's sandbox works inside the AppImage.
mkdir -p "$HOME/.local/share/applications"
cat <<EOF > "$HOME/.local/share/applications/obsidian.desktop"
[Desktop Entry]
Name=Obsidian
Exec=$HOME/.local/bin/obsidian %U
Terminal=false
Type=Application
Icon=obsidian
StartupWMClass=obsidian
Comment=Obsidian Markdown Note-taking
Categories=Office;
EOF

# --- THORIUM BROWSER (NEWEST VERIFIED AVX2 / SSE4 APPIMAGE + EXTENSIONS + GTK THEME) ---
# update-thorium.sh installs or updates to the newest checksum-verified build (also runs at i3 login)
bash "$DOTFILES_DIR/scripts/update-thorium.sh" || echo "[!] Thorium could not be installed/updated (continuing setup)."

# Create the .desktop entry for Thorium in Rofi
mkdir -p "$HOME/.local/share/applications"
cat <<EOF > "$HOME/.local/share/applications/thorium.desktop"
[Desktop Entry]
Name=Thorium Browser
GenericName=Web Browser
Exec=$HOME/.local/bin/thorium --no-default-browser-check %U
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

# Thorium default web fonts -> Iosevka (pages without their own web fonts use these).
# Thorium rewrites Preferences on exit, so this only runs while Thorium is closed.
THORIUM_PREFS="$HOME/.config/thorium/Default/Preferences"
if [ -f "$THORIUM_PREFS" ] && ! pgrep -x thorium >/dev/null; then
    THORIUM_TMP=$(mktemp "$THORIUM_PREFS.XXXXXX")
    if jq '.webkit.webprefs.fonts = ((.webkit.webprefs.fonts // {}) + {
            "standard":  {"Zyyy": "Iosevka Nerd Font"},
            "sansserif": {"Zyyy": "Iosevka Nerd Font"},
            "serif":     {"Zyyy": "Iosevka Nerd Font"},
            "fixed":     {"Zyyy": "Iosevka Nerd Font Mono"}
        })' "$THORIUM_PREFS" > "$THORIUM_TMP"; then
        mv "$THORIUM_TMP" "$THORIUM_PREFS"
        echo "[OK] Thorium default web fonts set to Iosevka."
    else
        rm -f "$THORIUM_TMP"
    fi
elif pgrep -x thorium >/dev/null; then
    echo "[!] Thorium is running: close it and re-run setup.sh to set its default web fonts."
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
SPICETIFY_CURRENT=""
[ -x "$HOME/.spicetify/spicetify" ] && SPICETIFY_CURRENT=$("$HOME/.spicetify/spicetify" -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)
if gh_check_update "spicetify/cli" '^spicetify-[0-9.]+-linux-amd64\.tar\.gz$' "$SPICETIFY_CURRENT"; then
    echo " -> Installing Spicetify $GH_LATEST_VERSION (installed: ${SPICETIFY_CURRENT:-none})..."
    SPICETIFY_TGZ=$(mktemp -d)/spicetify.tar.gz
    if gh_download_verified "$GH_URL" "$GH_DIGEST" "$SPICETIFY_TGZ"; then
        # Themes & config live in ~/.config/spicetify, so replacing the program files is safe
        mkdir -p "$HOME/.spicetify"
        tar -xzf "$SPICETIFY_TGZ" -C "$HOME/.spicetify"
        chmod +x "$HOME/.spicetify/spicetify"
        echo "[OK] Spicetify $GH_LATEST_VERSION installed."
    else
        echo "[!] Spicetify could not be installed/updated (continuing setup)."
    fi
    rm -rf "$(dirname "$SPICETIFY_TGZ")"
elif [ $? -eq 1 ]; then
    echo "[OK] Spicetify is up to date ($SPICETIFY_CURRENT)."
else
    echo "[!] Could not check for Spicetify updates (offline or GitHub API limit)."
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
# 5. Install Iosevka Nerd Font (User & System-wide for LightDM)
# ==========================================
echo "==> Installing Iosevka Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
SYS_FONT_DIR="/usr/local/share/fonts/Iosevka"

# Iosevka replaced JetBrainsMono: remove the old copies (user + system-wide for LightDM)
if [ -d "$FONT_DIR/JetBrainsMono" ] || [ -d /usr/local/share/fonts/JetBrainsMono ]; then
    rm -rf "$FONT_DIR/JetBrainsMono"
    sudo rm -rf /usr/local/share/fonts/JetBrainsMono
    echo "[OK] Removed the old JetBrainsMono Nerd Font."
fi

if [ ! -f "$FONT_DIR/Iosevka/IosevkaNerdFont-Regular.ttf" ]; then
    # The .tar.xz has the same fonts as the 384 MB .zip in 87 MB. Only Regular/Bold/Italic/BoldItalic
    # of "Iosevka Nerd Font" (UI, bars, menus) and "Iosevka Nerd Font Mono" (terminal) are kept.
    FONT_TMP=$(mktemp -d)
    if gh_install_latest "ryanoasis/nerd-fonts" '^Iosevka\.tar\.xz$' "$FONT_TMP/Iosevka.tar.xz"; then
        mkdir -p "$FONT_DIR/Iosevka"
        for style in Regular Bold Italic BoldItalic; do
            tar -xJf "$FONT_TMP/Iosevka.tar.xz" -C "$FONT_DIR/Iosevka" \
                "IosevkaNerdFont-$style.ttf" "IosevkaNerdFontMono-$style.ttf"
        done
        tar -xJf "$FONT_TMP/Iosevka.tar.xz" -C "$FONT_DIR/Iosevka" LICENSE.md 2>/dev/null || true
        fc-cache -f
        echo "[OK] Iosevka Nerd Font installed in ~/.local/share/fonts."
    else
        echo "[!] Iosevka Nerd Font could not be installed (continuing setup)."
    fi
    rm -rf "$FONT_TMP"
fi

# The LightDM greeter runs as the 'lightdm' user and cannot see ~/.local/share/fonts
if [ -d "$FONT_DIR/Iosevka" ] && [ ! -d "$SYS_FONT_DIR" ]; then
    sudo mkdir -p "$SYS_FONT_DIR"
    sudo cp -rf "$FONT_DIR/Iosevka/"* "$SYS_FONT_DIR/"
    sudo chmod -R a+rX "$SYS_FONT_DIR"
    sudo fc-cache -f
    echo "[OK] Font installed system-wide for LightDM."
fi

# ==========================================
# 6. Install Pywal (AI Color Engine)
# ==========================================
echo "==> Installing Pywal and Python dependencies..."
sudo nala install -y python3-pip python3-venv imagemagick

echo "==> Creating virtual environment for Pywal in ~/.local/pywal-venv..."
python3 -m venv "$HOME/.local/pywal-venv"
"$HOME/.local/pywal-venv/bin/pip" install --upgrade pip pywal
ln -sf "$HOME/.local/pywal-venv/bin/wal" "$LOCAL_BIN/wal"

# ==========================================
# 7. Dotfiles Symlinks Setup
# ==========================================
echo "==> Creating symlinks for configuration directories..."
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR"

APPS=("i3" "kitty" "polybar" "feh" "rofi" "nvim" "picom" "btop" "dunst" "zathura" "autorandr" "fontconfig")

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

# Migrate existing hotkeys.conf files: add the area screenshot hotkey once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/screenshot.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym Control+Shift+t exec --no-startup-id ~/dotfiles/scripts/screenshot.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added screenshot hotkey (Control+Shift+t) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the notification hotkeys once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/notifications.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym $mod+n exec --no-startup-id ~/dotfiles/scripts/notifications.sh toggle\nbindsym $mod+Shift+n exec --no-startup-id ~/dotfiles/scripts/notifications.sh menu' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added notification hotkeys (\$mod+n / \$mod+Shift+n) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: volume keys step 5% instead of 10%
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && grep -Fq 'set-sink-volume @DEFAULT_SINK@ +10%' "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i 's/set-sink-volume @DEFAULT_SINK@ +10%/set-sink-volume @DEFAULT_SINK@ +5%/; s/set-sink-volume @DEFAULT_SINK@ -10%/set-sink-volume @DEFAULT_SINK@ -5%/' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Volume keys now step 5% in existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: power menu replaces the i3-nagbar exit prompt
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/power-menu.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i 's|^bindsym \$mod+Shift+e exec "i3-nagbar.*$|bindsym $mod+Shift+e exec --no-startup-id ~/dotfiles/scripts/power-menu.sh|' "$DOTFILES_DIR/i3/hotkeys.conf"
    grep -Fq "scripts/power-menu.sh" "$DOTFILES_DIR/i3/hotkeys.conf" \
        || echo 'bindsym $mod+Shift+e exec --no-startup-id ~/dotfiles/scripts/power-menu.sh' >> "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Power menu bound to \$mod+Shift+e in existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the Rofi tools (clipboard, calculator, emoji) once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/clipboard.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym $mod+c exec --no-startup-id ~/dotfiles/scripts/clipboard.sh menu\nbindsym $mod+equal exec --no-startup-id ~/dotfiles/scripts/calculator.sh\nbindsym $mod+Shift+period exec --no-startup-id ~/dotfiles/scripts/emoji.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added clipboard (\$mod+c), calculator (\$mod+equal) and emoji (\$mod+Shift+period) hotkeys to existing i3/hotkeys.conf."
fi

# ==========================================
# 8. Set Executable Permissions & Screen Lock CLI
# ==========================================
echo "==> Setting executable permissions on scripts..."

if [ -f "$DOTFILES_DIR/polybar/launch.sh" ]; then
    chmod +x "$DOTFILES_DIR/polybar/launch.sh"
fi

chmod +x "$DOTFILES_DIR/scripts/"*.sh
[ -f "$DOTFILES_DIR/autorandr/postswitch" ] && chmod +x "$DOTFILES_DIR/autorandr/postswitch"
ln -sf "$DOTFILES_DIR/scripts/lock.sh" "$LOCAL_BIN/lock"

echo "==> Setting default applications (Thorium, Zathura, imv, mpv, Thunar)..."
bash "$DOTFILES_DIR/scripts/default-apps.sh"

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
