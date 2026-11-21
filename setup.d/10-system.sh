# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/10-system.sh: part of setup.sh, sourced in order in the same shell (not run on its own)

# ==========================================
# 2.5 Clean APT Sources (runs after the re-exec, so it also repairs machines where an
#     older setup.sh just added nala's extra mirrors)
# ==========================================
if [ -f /etc/apt/sources.list.d/fetch.sources ]; then
    log "Removing nala fetch mirrors (mixed mirrors can break package installs)..."
    sudo rm -f /etc/apt/sources.list.d/fetch.sources
    sudo apt update
fi

# ==========================================
# 3. Xorg, Display Manager & Applications
# ==========================================
log "Installing Xorg and LightDM..."
sudo nala install -y xserver-xorg xinit lightdm lightdm-gtk-greeter light-locker
sudo systemctl enable lightdm

log "Installing audio stack (PipeWire + WirePlumber, Pulse/ALSA compatibility, SOF firmware)..."
sudo nala install -y pipewire pipewire-pulse pipewire-alsa wireplumber pulseaudio-utils alsa-utils pavucontrol firmware-sof-signed
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

log "Installing applications & CLI tools (including JQ and NPM)..."
# desktop-file-utils/xdg-utils: update-desktop-database and xdg-mime (launchers, default apps)
sudo nala install -y i3 kitty polybar feh rofi wget unzip fontconfig libfuse2 fuse picom psmisc fastfetch thunar btop jq playerctl maim xclip xdg-user-dirs dunst libnotify-bin yad desktop-file-utils xdg-utils

# --- SPOTIFY (official apt repo; installs /usr/share/applications/spotify.desktop so it shows up in Rofi) ---
# ==========================================
# 3.5 Desktop Essentials
# ==========================================
log "Installing desktop essentials (network, polkit, viewers, archives, Rofi tools, displays, backups)..."
# network-manager(-gnome): Wi-Fi/VPN (nmtui + nm-connection-editor)  mate-polkit: GUI password prompts (pkexec)
# wpasupplicant/iw: Wi-Fi backend for NetworkManager, link info for the polybar module (both only Recommends)
# zathura/imv/mpv: PDF, image & media viewers               thunar-archive-plugin/xarchiver: "Extract here"
# gvfs-backends: phones (MTP), SMB/SFTP shares in Thunar     qalc/xdotool/unicode-data/noto emoji: Rofi tools
# autorandr/arandr: monitor profiles & layout GUI            timeshift: system snapshots
# earlyoom/zram-tools: low-memory protection
sudo nala install -y \
    network-manager network-manager-gnome wpasupplicant iw mate-polkit \
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
sudo systemctl restart zramswap || warn "zramswap could not be started (continuing setup)."

# earlyoom: kill the biggest browser/Electron process before the whole desktop freezes.
# (No quotes inside EARLYOOM_ARGS: systemd splits it on spaces and passes quotes literally.)
echo 'EARLYOOM_ARGS="-r 3600 --prefer ^(thorium|chrome|obsidian|spotify)$ --avoid ^(init|systemd|Xorg|i3|polybar|lightdm|sshd|dunst|kitty)$"' \
    | sudo tee /etc/default/earlyoom >/dev/null
sudo systemctl enable earlyoom >/dev/null 2>&1 || true
sudo systemctl restart earlyoom || warn "earlyoom could not be started (continuing setup)."

# --- Laptop only: battery power management (TLP) ---
if ls -d /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    log "Battery detected: installing TLP power management..."
    sudo nala install -y tlp
    sudo systemctl enable --now tlp
else
    ok "No battery detected: skipping TLP."
fi

# --- Bluetooth only when the machine has a Bluetooth controller ---
# /sys/class/bluetooth lists loaded controllers; USB class e0/01/01 catches adapters without a loaded driver.
HAS_BLUETOOTH=0
[ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] && HAS_BLUETOOTH=1
for usb_if in /sys/bus/usb/devices/*:*; do
    [ "$(cat "$usb_if/bInterfaceClass" 2>/dev/null)$(cat "$usb_if/bInterfaceSubClass" 2>/dev/null)$(cat "$usb_if/bInterfaceProtocol" 2>/dev/null)" = "e00101" ] && HAS_BLUETOOTH=1
done
if [ "$HAS_BLUETOOTH" = 1 ]; then
    log "Bluetooth controller detected: installing BlueZ + Blueman (pairing agent, no tray icon) + PipeWire Bluetooth audio..."
    # libspa-0.2-bluetooth: PipeWire A2DP/HFP profiles; without it headphones fail with br-connection-profile-unavailable
    sudo nala install -y bluez blueman libspa-0.2-bluetooth
    # Keep blueman-applet (pairing agent) but drop its tray icon: polybar's bluetooth module replaces it
    python3 -c "from gi.repository import Gio; s = Gio.Settings.new('org.blueman.general'); s.set_strv('plugin-list', ['!StatusIcon', '!ShowConnected']); Gio.Settings.sync()" \
        || warn "Could not hide the Blueman tray icon."
    # USB autosuspend makes many Bluetooth adapters (notably Realtek Wi-Fi/BT combo chips) drop out
    # briefly, which is heard as audio stutter on headphones; the power saving is negligible
    echo 'options btusb enable_autosuspend=0' | sudo tee /etc/modprobe.d/btusb-no-autosuspend.conf >/dev/null
    # TLP (laptops) turns USB autosuspend back on at runtime for every device, btusb included, which undoes
    # the module option above on battery: exclude Bluetooth adapters from TLP's USB autosuspend
    if [ -d /etc/tlp.d ]; then
        printf '# Written by dotfiles setup.sh: no USB autosuspend for Bluetooth (audio stutter)\nUSB_EXCLUDE_BTUSB=1\n' \
            | sudo tee /etc/tlp.d/50-dotfiles-bluetooth.conf >/dev/null
    fi
    sudo systemctl enable --now bluetooth
else
    ok "No Bluetooth controller detected: skipping Bluetooth."
fi

# --- Bare metal only: firmware updates (BIOS, SSD, peripherals) via LVFS ---
if systemd-detect-virt -q; then
    ok "Virtual machine detected: skipping fwupd."
else
    log "Bare metal detected: installing fwupd (run 'fwupdmgr get-updates' to check firmware)..."
    sudo nala install -y fwupd
fi

# ==========================================
# 3.6 Network (NetworkManager owns Wi-Fi)
# ==========================================
log "Configuring networking (NetworkManager + wpa_supplicant)..."
# NetworkManager needs wpa_supplicant.service (D-Bus activated) for every Wi-Fi operation. Installing the
# packages doesn't repair a masked or disabled unit (postinst doesn't run again when they are already installed),
# and a masked unit makes Wi-Fi fail with "wpa_supplicant couldn't grab this interface".
for unit in wpa_supplicant NetworkManager; do
    if [ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" = masked ]; then
        warn "$unit.service was masked: unmasking it."
        sudo systemctl unmask "$unit"
    fi
done
sudo systemctl enable wpa_supplicant NetworkManager >/dev/null 2>&1 || warn "Could not enable NetworkManager/wpa_supplicant."
sudo systemctl start NetworkManager || warn "NetworkManager could not be started (continuing setup)."
# Debian's polkit rule lets active local users in sudo OR netdev change system connections without a password;
# netdev also covers a desktop user without sudo rights (menu-wifi.sh adds and forgets profiles)
if getent group netdev >/dev/null && ! id -nG "$USER" | tr ' ' '\n' | grep -qx netdev; then
    sudo usermod -aG netdev "$USER"
fi

# Firmware for Realtek network chips (rtw88 Wi-Fi, r8169 Ethernet); the installer only adds it when it
# noticed the chip, and without it the Wi-Fi card has no interface at all (PCI class 0x02xxxx = network)
for pci in /sys/bus/pci/devices/*; do
    if [ "$(cat "$pci/vendor" 2>/dev/null)" = 0x10ec ] && [[ "$(cat "$pci/class" 2>/dev/null)" == 0x02* ]]; then
        sudo nala install -y firmware-realtek || warn "firmware-realtek could not be installed (non-free-firmware missing from APT sources?)."
        break
    fi
done

# Realtek rtw88 Wi-Fi/BT combo chips (e.g. RTL8821CE). Deep power save (LPS deep) and PCIe ASPM make the Wi-Fi
# side drop out and stall the Bluetooth side of the chip (micro-stutter on headphones, even on 5 GHz).
# Not tied to Bluetooth: it also matters for Wi-Fi alone. Takes effect after a reboot.
if [ -d /sys/module/rtw88_core ]; then
    rtw88_opts=$'options rtw88_core disable_lps_deep=1\noptions rtw88_pci disable_aspm=1'
    if [ "$(cat /etc/modprobe.d/rtw88-bt-coex.conf 2>/dev/null)" != "$rtw88_opts" ]; then
        printf '%s\n' "$rtw88_opts" | sudo tee /etc/modprobe.d/rtw88-bt-coex.conf >/dev/null
        NEEDS_REBOOT=1   # module options only apply when the driver loads (reminder in setup.d/95-network.sh)
    fi
    # TLP (laptops) switches normal Wi-Fi power save on and lets the card runtime-suspend on battery, which brings
    # the same dropouts back on battery only. TLP is the one tool that sets these (no NetworkManager powersave
    # setting on top, or two tools would fight over it).
    if [ -d /etc/tlp.d ]; then
        rtw_drivers=""
        for drv in /sys/bus/pci/drivers/rtw_*; do
            [ -d "$drv" ] && rtw_drivers+="${rtw_drivers:+ }${drv##*/}"
        done
        # (TLP's += appends with a space; settings come in AC/BAT pairs)
        printf '# Written by dotfiles setup.sh: Realtek rtw88 Wi-Fi drops out with power saving on\nWIFI_PWR_ON_AC=off\nWIFI_PWR_ON_BAT=off\n%s\n' \
            "${rtw_drivers:+RUNTIME_PM_DRIVER_DENYLIST+=\"$rtw_drivers\"}" \
            | sudo tee /etc/tlp.d/50-dotfiles-rtw88.conf >/dev/null
    fi
fi
# Apply the TLP drop-ins (this file and the Bluetooth one) now instead of at the next power change
# (tlp is in /usr/sbin, which isn't on a normal user's PATH on Debian: test the path, sudo finds it)
if [ -d /etc/tlp.d ] && [ -x /usr/sbin/tlp ]; then
    sudo tlp start >/dev/null 2>&1 || warn "TLP could not apply its settings (continuing setup)."
fi

# Wi-Fi that the Debian installer configured in /etc/network/interfaces belongs to ifupdown, and NetworkManager
# ([ifupdown] managed=false) leaves it alone: only that one network works and the Wi-Fi menu stays empty.
# setup.d/95-network.sh hands it over to NetworkManager at the very end of the setup, so the downloads in between
# keep the connection. The file is root-only (0600, it holds the Wi-Fi password), hence sudo for the check.
WIFI_IN_IFUPDOWN=0
if sudo sh -c "grep -qsE '^[[:space:]]*(auto|allow-hotplug|allow-[a-z]+|iface)[[:space:]]+(.*[[:space:]])?wl' /etc/network/interfaces /etc/network/interfaces.d/*"; then
    WIFI_IN_IFUPDOWN=1
fi

# No nm-applet tray icon: polybar's wifi module (click: menu-wifi.sh, right-click: nmtui) replaces it. network-manager-gnome
# ships an XDG autostart entry that dex would start at login, so hide it for this user.
mkdir -p "$HOME/.config/autostart"
printf '[Desktop Entry]\nType=Application\nName=nm-applet (disabled: replaced by polybar wifi module)\nHidden=true\n' \
    > "$HOME/.config/autostart/nm-applet.desktop"
# One polkit agent only: i3 starts mate-polkit; lxpolkit (pulled in by pcmanfm) also autostarts via dex, and the
# second agent fails with "An authentication agent already exists for the given subject"
printf '[Desktop Entry]\nType=Application\nName=LXPolKit (disabled: mate-polkit is the agent)\nHidden=true\n' \
    > "$HOME/.config/autostart/lxpolkit.desktop"
# One picom only: i3 starts it via scripts/picom-launch.sh (glx on bare metal). The picom package also ships an XDG
# autostart entry that dex starts without arguments, so it reads backend = xrender from picom.conf and can win the
# race against the launcher: xrender + vsync makes fast-updating windows (noVNC consoles, video) flicker
printf '[Desktop Entry]\nType=Application\nName=picom (disabled: i3 starts picom-launch.sh)\nHidden=true\n' \
    > "$HOME/.config/autostart/picom.desktop"
# i3/config starts these itself, with the right arguments. Their packages' XDG autostart entries make dex start a
# second copy: a second polkit agent that fails, autorandr twice, and a bare `light-locker` that can win the race
# against i3's pgrep guard, so the session runs without --lock-on-suspend and --lock-after-screensaver
for entry in polkit-mate-authentication-agent-1 light-locker autorandr; do
    printf '[Desktop Entry]\nType=Application\nName=%s (disabled: i3/config starts it)\nHidden=true\n' "$entry" \
        > "$HOME/.config/autostart/$entry.desktop"
done

# ~/.local/bin (node, ob, obsidian, ...) on PATH for the whole desktop session: LightDM's X session reads
# ~/.xsessionrc, not ~/.profile, so without this i3, rofi and their scripts can't find them
if ! grep -qs 'HOME/.local/bin' "$HOME/.xsessionrc"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    printf '# Added by dotfiles setup.sh: user binaries (node, ob, ...) for i3 and everything it starts\ncase ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac\n' >> "$HOME/.xsessionrc"
fi

log "Enabling automatic security updates (unattended-upgrades)..."
sudo nala install -y unattended-upgrades
# Daily package list refresh + unattended upgrade run (Debian security & stable point releases)
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' \
    | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null

log "Installing Spotify from the official repository..."
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
        ln -sfn /usr/share/spotify/spotify.desktop "$HOME/.local/share/applications/spotify.desktop"
        ok "Spotify installed."
    else
        warn "Spotify install failed (continuing setup)."
        sudo rm -f /etc/apt/sources.list.d/spotify.list
    fi
else
    warn "Could not fetch Spotify signing key (continuing setup)."
fi

