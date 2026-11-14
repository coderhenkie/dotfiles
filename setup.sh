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

    # No 'nala fetch': it adds extra mirrors on every run, and mixing mirrors that are not in sync
    # breaks installs ("held broken packages"). The Debian installer's mirror is used as-is.
    sudo rm -f /etc/apt/sources.list.d/fetch.sources

    echo "==> Upgrading system via Nala..."
    sudo nala upgrade -y

    # ==========================================
    # 2. Fetch Latest Dotfiles & Re-exec Latest Setup Script
    # ==========================================
    echo "==> Fetching latest dotfiles..."

    # choose <prompt> <option>...: interactive picker on the terminal (j/k or arrow keys, Enter).
    # Sets CHOICE to the index of the picked option. Reads /dev/tty, so it also works when this
    # script itself is piped in (curl ... | bash).
    choose() {
        local prompt="$1" sel=0 key i n
        shift
        local -a opts=("$@")
        n=${#opts[@]}
        printf '%s  (j/k or arrows, Enter)\n' "$prompt" >/dev/tty
        printf '\e[?25l' >/dev/tty
        while true; do
            for i in "${!opts[@]}"; do
                if [ "$i" -eq "$sel" ]; then
                    printf '\e[2K  \e[1;36m> %s\e[0m\n' "${opts[$i]}"
                else
                    printf '\e[2K    %s\n' "${opts[$i]}"
                fi
            done >/dev/tty
            IFS= read -rsn1 key </dev/tty || key=""
            if [ "$key" = $'\e' ]; then
                IFS= read -rsn2 -t 0.05 key </dev/tty || true
                [ -z "$key" ] && key="esc"
            fi
            case "$key" in
                j|'[B') sel=$(( (sel + 1) % n )) ;;
                k|'[A') sel=$(( (sel - 1 + n) % n )) ;;
                '') break ;;   # Enter
            esac
            printf '\e[%dA' "$n" >/dev/tty
        done
        printf '\e[?25h' >/dev/tty
        CHOICE=$sel
    }

    if [ -d "$DOTFILES_DIR/.git" ]; then
        echo "==> Dotfiles directory already exists. Syncing with latest origin/main..."
        git -C "$DOTFILES_DIR" fetch origin
        DOTFILES_UPDATE=1
        LOCAL_CHANGES=$(git -C "$DOTFILES_DIR" status --short)
        LOCAL_COMMITS=$(git -C "$DOTFILES_DIR" log --oneline origin/main..HEAD)

        # The update below is a hard reset to origin/main: never let it silently destroy local work
        if [ -n "$LOCAL_CHANGES" ] || [ -n "$LOCAL_COMMITS" ]; then
            echo
            echo "[!] $DOTFILES_DIR has local work that the update to origin/main would overwrite:"
            [ -n "$LOCAL_CHANGES" ] && { echo "    Uncommitted changes:"; sed 's/^/      /' <<< "$LOCAL_CHANGES"; }
            [ -n "$LOCAL_COMMITS" ] && { echo "    Commits not pushed to origin/main:"; sed 's/^/      /' <<< "$LOCAL_COMMITS"; }
            echo
            BACKUP_REF="setup-backup-$(date +%Y%m%d-%H%M%S)"
            if ( : </dev/tty ) 2>/dev/null; then
                choose "What should happen with these changes?" \
                    "Save them (stash + backup branch), then update to origin/main" \
                    "Discard them and update to origin/main" \
                    "Keep them: skip the update and run setup with the local version" \
                    "Abort setup"
            else
                echo "[!] No terminal to ask on: saving the changes before updating."
                CHOICE=0
            fi
            case "$CHOICE" in
                0)
                    if [ -n "$LOCAL_COMMITS" ]; then
                        git -C "$DOTFILES_DIR" branch "$BACKUP_REF"
                        echo "[OK] Local commits saved in branch '$BACKUP_REF'."
                        echo "     Bring them back with: git -C ~/dotfiles merge $BACKUP_REF"
                    fi
                    if [ -n "$LOCAL_CHANGES" ]; then
                        git -C "$DOTFILES_DIR" stash push -u -m "$BACKUP_REF" >/dev/null
                        echo "[OK] Uncommitted changes stashed as '$BACKUP_REF'."
                        echo "     Restore them with: git -C ~/dotfiles stash pop"
                    fi
                    ;;
                1) echo "==> Discarding local changes." ;;
                2) DOTFILES_UPDATE=0; echo "==> Keeping local changes; setup runs with the local version." ;;
                *) echo "==> Setup aborted; nothing was changed in $DOTFILES_DIR."; exit 1 ;;
            esac
        fi

        if [ "$DOTFILES_UPDATE" = 1 ]; then
            git -C "$DOTFILES_DIR" reset --hard origin/main
        fi
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
# 2.5 Clean APT Sources (runs after the re-exec, so it also repairs machines where an
#     older setup.sh just added nala's extra mirrors)
# ==========================================
if [ -f /etc/apt/sources.list.d/fetch.sources ]; then
    echo "==> Removing nala fetch mirrors (mixed mirrors can break package installs)..."
    sudo rm -f /etc/apt/sources.list.d/fetch.sources
    sudo apt update
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
# network-manager(-gnome): Wi-Fi/VPN (nmtui + nm-connection-editor)  mate-polkit: GUI password prompts (pkexec)
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
    echo "==> Bluetooth controller detected: installing BlueZ + Blueman (pairing agent, no tray icon) + PipeWire Bluetooth audio..."
    # libspa-0.2-bluetooth: PipeWire A2DP/HFP profiles; without it headphones fail with br-connection-profile-unavailable
    sudo nala install -y bluez blueman libspa-0.2-bluetooth
    # Keep blueman-applet (pairing agent) but drop its tray icon: polybar's bluetooth module replaces it
    python3 -c "from gi.repository import Gio; s = Gio.Settings.new('org.blueman.general'); s.set_strv('plugin-list', ['!StatusIcon', '!ShowConnected']); Gio.Settings.sync()" \
        || echo "[!] Could not hide the Blueman tray icon."
    # USB autosuspend makes many Bluetooth adapters (notably Realtek Wi-Fi/BT combo chips) drop out
    # briefly, which is heard as audio stutter on headphones; the power saving is negligible
    echo 'options btusb enable_autosuspend=0' | sudo tee /etc/modprobe.d/btusb-no-autosuspend.conf >/dev/null
    # Realtek rtw88 Wi-Fi/BT combo chips (e.g. RTL8821CE): Wi-Fi deep power save (LPS deep) and PCIe ASPM
    # also stall the Bluetooth side of the chip, heard as micro-stutter on headphones (even on 5 GHz)
    if lsmod | grep -q '^rtw88_core'; then
        printf 'options rtw88_core disable_lps_deep=1\noptions rtw88_pci disable_aspm=1\n' \
            | sudo tee /etc/modprobe.d/rtw88-bt-coex.conf >/dev/null
    fi
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
# managed by NetworkManager; it is never changed automatically because that could cut the connection.
if grep -qsE '^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+wl' /etc/network/interfaces /etc/network/interfaces.d/*; then
    echo "[!] Wi-Fi is configured in /etc/network/interfaces, so NetworkManager cannot manage it."
    echo "    To hand it to NetworkManager: comment out the wl* lines there and reboot (do this locally, not over SSH)."
fi

# No nm-applet tray icon: polybar's wifi module (click: nmtui) replaces it. network-manager-gnome
# ships an XDG autostart entry that dex would start at login, so hide it for this user.
mkdir -p "$HOME/.config/autostart"
printf '[Desktop Entry]\nType=Application\nName=nm-applet (disabled: replaced by polybar wifi module)\nHidden=true\n' \
    > "$HOME/.config/autostart/nm-applet.desktop"

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

# Thorium default web fonts -> generic families. Fontconfig maps those to the active font module
# ($mod+Shift+f), so web pages follow the font picker without touching Thorium again.
# Thorium rewrites Preferences on exit, so this only runs while Thorium is closed.
THORIUM_PREFS="$HOME/.config/thorium/Default/Preferences"
if [ -f "$THORIUM_PREFS" ] && ! pgrep -x thorium >/dev/null; then
    THORIUM_TMP=$(mktemp "$THORIUM_PREFS.XXXXXX")
    if jq '.webkit.webprefs.fonts = ((.webkit.webprefs.fonts // {}) + {
            "standard":  {"Zyyy": "sans-serif"},
            "sansserif": {"Zyyy": "sans-serif"},
            "serif":     {"Zyyy": "serif"},
            "fixed":     {"Zyyy": "monospace"}
        })' "$THORIUM_PREFS" > "$THORIUM_TMP"; then
        mv "$THORIUM_TMP" "$THORIUM_PREFS"
        echo "[OK] Thorium default web fonts follow the active font."
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

# --- Starship prompt + terminal CLI tools (Debian packages; colored by the Color Engine) ---
# starship: prompt (starship/init.bash)   fzf: fuzzy finder   ripgrep: fast grep (rg)
# fd-find: fast find   bat: cat with syntax highlighting   zoxide: jump to frequent folders (z)
echo " -> Installing Starship prompt and CLI tools (fzf, ripgrep, fd, bat, zoxide)..."
sudo nala install -y starship fzf ripgrep fd-find bat zoxide
# Debian ships fd and bat as fdfind and batcat (name clashes with other packages)
ln -sf /usr/bin/fdfind "$LOCAL_BIN/fd"
ln -sf /usr/bin/batcat "$LOCAL_BIN/bat"
echo "[OK] Starship and CLI tools installed."

# --- Claude Code ---
echo " -> Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
echo "[OK] Claude Code installed."

# ==========================================
# 4.8 PATH configuration for ~/.local/bin
# ==========================================
echo "==> Checking PATH for ~/.local/bin..."
# Look for the literal line written below (grepping the expanded $HOME never matched it,
# so every run appended another copy)
if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "[OK] Added ~/.local/bin to ~/.bashrc"
fi
# Remove the extra copies that older runs of this script added (keeps the first one)
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if [ "$(grep -cFx "$PATH_LINE" "$HOME/.bashrc")" -gt 1 ]; then
    BASHRC_TMP=$(mktemp)
    awk -v line="$PATH_LINE" '$0 == line { if (seen++) next } 1' "$HOME/.bashrc" > "$BASHRC_TMP"
    cat "$BASHRC_TMP" > "$HOME/.bashrc"
    rm -f "$BASHRC_TMP"
    echo "[OK] Removed duplicate ~/.local/bin PATH lines from ~/.bashrc"
fi

# CLI tools (fzf key bindings, zoxide, bat/ripgrep config): logic lives in cli/init.bash
if ! grep -Fq 'dotfiles/cli/init.bash' "$HOME/.bashrc"; then
    printf '\n# CLI tools: fzf, ripgrep, fd, bat, zoxide (added by ~/dotfiles/setup.sh)\n[ -f "$HOME/dotfiles/cli/init.bash" ] && . "$HOME/dotfiles/cli/init.bash"\n' >> "$HOME/.bashrc"
    echo "[OK] Added the CLI tools to ~/.bashrc"
fi

# Starship prompt: one source line, the logic lives in the repo (starship/init.bash)
if ! grep -Fq 'dotfiles/starship/init.bash' "$HOME/.bashrc"; then
    printf '\n# Starship prompt, colored by the Color Engine (added by ~/dotfiles/setup.sh)\n[ -f "$HOME/dotfiles/starship/init.bash" ] && . "$HOME/dotfiles/starship/init.bash"\n' >> "$HOME/.bashrc"
    echo "[OK] Added the Starship prompt to ~/.bashrc"
fi

# ==========================================
# 5. Fonts (modules in ~/dotfiles/fonts, picker: $mod+Shift+f)
# ==========================================
echo "==> Installing fonts..."
# shellcheck source=scripts/lib/fonts.sh
source "$DOTFILES_DIR/scripts/lib/fonts.sh"

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
fc-cache -f >/dev/null 2>&1

# Install every font module, so the picker ($mod+Shift+f) switches instantly without downloading
for font_id in $(font_ids); do
    if font_is_installed "$font_id"; then
        echo "[OK] $FONT_NAME Nerd Font is installed."
    else
        font_install "$font_id" || echo "[!] $font_id font could not be installed (continuing setup)."
    fi
done

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

# Migrate existing hotkeys.conf files: the Rofi tools were renamed to scripts/menu-*.sh
# (must run before the migrations below, which look for the new names)
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ]; then
    sed -i -E \
        -e 's#scripts/theme-selector\.sh#scripts/menu-theme.sh#g' \
        -e 's#scripts/ai-theme\.sh#scripts/menu-wallpaper.sh#g' \
        -e 's#scripts/font-picker\.sh#scripts/menu-font.sh#g' \
        -e 's#scripts/hotkey-menu\.sh#scripts/menu-hotkeys.sh#g' \
        -e 's#scripts/power-menu\.sh#scripts/menu-power.sh#g' \
        -e 's#scripts/clipboard\.sh#scripts/menu-clipboard.sh#g' \
        -e 's#scripts/calculator\.sh#scripts/menu-calc.sh#g' \
        -e 's#scripts/emoji\.sh#scripts/menu-emoji.sh#g' \
        -e 's#scripts/notifications\.sh#scripts/menu-notifications.sh#g' \
        "$DOTFILES_DIR/i3/hotkeys.conf"
fi

# Initialize local i3 hotkeys.conf from hotkeys.default only on first install
if [ ! -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && [ -f "$DOTFILES_DIR/i3/hotkeys.default" ]; then
    cp "$DOTFILES_DIR/i3/hotkeys.default" "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Initialized i3/hotkeys.conf from hotkeys.default."
elif [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/lock.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/menu-hotkeys\.sh/a bindsym $mod+Shift+x exec --no-startup-id ~/dotfiles/scripts/lock.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added screen lock hotkey (\$mod+Shift+x) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the area screenshot hotkey once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/screenshot.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym Control+Shift+t exec --no-startup-id ~/dotfiles/scripts/screenshot.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added screenshot hotkey (Control+Shift+t) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the notification hotkeys once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-notifications.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym $mod+n exec --no-startup-id ~/dotfiles/scripts/menu-notifications.sh toggle\nbindsym $mod+Shift+n exec --no-startup-id ~/dotfiles/scripts/menu-notifications.sh menu' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added notification hotkeys (\$mod+n / \$mod+Shift+n) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the font picker once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-font.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym $mod+Shift+f exec --no-startup-id ~/dotfiles/scripts/menu-font.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added font picker hotkey (\$mod+Shift+f) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the UI scale hotkeys once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/ui-scale.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/menu-font\.sh/a bindsym $mod+Shift+equal exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh up\nbindsym $mod+Shift+minus exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh down\nbindsym $mod+Shift+KP_Add exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh up\nbindsym $mod+Shift+KP_Subtract exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh down\nbindsym $mod+Shift+BackSpace exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh reset' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Added UI scale hotkeys (\$mod+Shift+plus / minus / BackSpace) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: volume keys step 5% instead of 10%
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && grep -Fq 'set-sink-volume @DEFAULT_SINK@ +10%' "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i 's/set-sink-volume @DEFAULT_SINK@ +10%/set-sink-volume @DEFAULT_SINK@ +5%/; s/set-sink-volume @DEFAULT_SINK@ -10%/set-sink-volume @DEFAULT_SINK@ -5%/' "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Volume keys now step 5% in existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: power menu replaces the i3-nagbar exit prompt
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-power.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i 's|^bindsym \$mod+Shift+e exec "i3-nagbar.*$|bindsym $mod+Shift+e exec --no-startup-id ~/dotfiles/scripts/menu-power.sh|' "$DOTFILES_DIR/i3/hotkeys.conf"
    grep -Fq "scripts/menu-power.sh" "$DOTFILES_DIR/i3/hotkeys.conf" \
        || echo 'bindsym $mod+Shift+e exec --no-startup-id ~/dotfiles/scripts/menu-power.sh' >> "$DOTFILES_DIR/i3/hotkeys.conf"
    echo "[OK] Power menu bound to \$mod+Shift+e in existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the Rofi tools (clipboard, calculator, emoji) once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-clipboard.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym $mod+c exec --no-startup-id ~/dotfiles/scripts/menu-clipboard.sh menu\nbindsym $mod+equal exec --no-startup-id ~/dotfiles/scripts/menu-calc.sh\nbindsym $mod+Shift+period exec --no-startup-id ~/dotfiles/scripts/menu-emoji.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
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
# autorandr hotplug: udev triggers this service on every plug/unplug (HDMI, dock, lid).
# Without saved profiles it falls back to autorandr/default -> common (mirror all screens).
sudo systemctl enable autorandr.service >/dev/null 2>&1 || echo "[!] autorandr.service could not be enabled (continuing setup)."
ln -sf "$DOTFILES_DIR/scripts/lock.sh" "$LOCAL_BIN/lock"

echo "==> Adding the dotfiles tools to Rofi (font picker, themes, clipboard, ...)..."
bash "$DOTFILES_DIR/scripts/desktop-entries.sh"

echo "==> Setting default applications (Thorium, Zathura, imv, mpv, Thunar)..."
bash "$DOTFILES_DIR/scripts/default-apps.sh"

# ==========================================
# 8.5 LightDM & light-locker Color Engine Integration
# ==========================================
echo "==> Configuring LightDM GTK Greeter and light-locker for Color Engine..."
bash "$DOTFILES_DIR/scripts/lockscreen-setup.sh"

# Auto-suspend after 30 min locked (scripts/lock-suspend.sh). A locked session is inactive for
# logind, which then asks for an admin password to suspend; this rule lets only this user suspend
# from a local session without one. Bare metal only: VMs never auto-suspend.
# shellcheck source=scripts/lib/machine.sh
source "$DOTFILES_DIR/scripts/lib/machine.sh"
if machine_is_vm; then
    echo "[OK] $(machine_type) detected: skipping auto-suspend polkit rule."
else
    echo "==> Bare metal detected: allowing suspend while locked (polkit rule)..."
    sudo tee /etc/polkit-1/rules.d/50-lock-suspend.rules >/dev/null <<POLKIT
// Managed by ~/dotfiles/setup.sh: lets $USER suspend while the screen is locked (lock-suspend.sh)
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions") &&
        subject.user == "$USER" && subject.local) {
        return polkit.Result.YES;
    }
});
POLKIT
fi

# ==========================================
# 9. Color Engine Bootstrap & Live Reload (Including LightDM, Thorium, Neovim, Herdr, btop & Spotify)
# ==========================================
echo "==> Generating theme files in ~/.cache/theme..."
CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

# Re-runs keep the active palette (theme selector / AI theme); Dracula only on a fresh install
THEME_FILE="$CACHE_DIR/current.theme"
[ -f "$THEME_FILE" ] || THEME_FILE="$DOTFILES_DIR/themes/dracula.theme"
# shellcheck disable=SC1090
source "$THEME_FILE"
BG="$bg" FG="$fg" ACCENT="$accent"

# HERDR config symlink (only link config.toml so live sockets/logs stay out of git)
mkdir -p "$HOME/.config/herdr"
ln -sf "$CACHE_DIR/herdr.toml" "$HOME/.config/herdr/config.toml"

# BTOP theme symlink
mkdir -p "$HOME/.config/btop/themes"
ln -sf "$CACHE_DIR/btop.theme" "$HOME/.config/btop/themes/color_engine.theme"

# UI scale snippets for Rofi & Polybar (keeps the saved scale; 100% on a fresh install)
bash "$DOTFILES_DIR/scripts/ui-scale.sh" files

# Generate all theme files, ColorEngine icons, and live-reload i3 if a session is active
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$BG" "$FG" "$ACCENT"

echo "[OK] Bootstrap theme generated and applied."
echo "[OK] Setup completed!"
