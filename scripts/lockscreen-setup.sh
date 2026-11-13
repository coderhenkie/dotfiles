#!/usr/bin/env bash

# ==========================================
# LightDM / light-locker Color Engine Provisioning (one-time, needs sudo)
# ==========================================
# Creates the user-writable system theme/icon dirs that the LightDM GTK greeter
# reads, writes the greeter config, installs the font system-wide, and then
# re-applies the active Color Engine palette so the lock screen matches the
# current wallpaper colors immediately.
#
# Safe to re-run. Called by setup.sh; can also be run standalone:
#   ~/dotfiles/scripts/lockscreen-setup.sh

set -eu

DOTFILES_DIR="$HOME/dotfiles"
CACHE_DIR="$HOME/.cache/theme"
SYS_THEME_DIR="/usr/share/themes/ColorEngine"
SYS_ICON_DIR="/usr/share/icons/ColorEngine"
FONT_DIR="$HOME/.local/share/fonts/Iosevka"
SYS_FONT_DIR="/usr/local/share/fonts/Iosevka"

echo "==> Provisioning LightDM ColorEngine theme directories..."
sudo mkdir -p "$SYS_THEME_DIR/gtk-3.0" "$SYS_ICON_DIR" /etc/lightdm/lightdm.conf.d
sudo chown -R "$USER:$USER" "$SYS_THEME_DIR" "$SYS_ICON_DIR"
sudo chmod -R a+rX,u+w "$SYS_THEME_DIR" "$SYS_ICON_DIR"

echo "==> Writing LightDM GTK greeter configuration..."
sudo tee /etc/lightdm/lightdm-gtk-greeter.conf >/dev/null <<EOF
[greeter]
theme-name=ColorEngine
icon-theme-name=ColorEngine
font-name=Iosevka Nerd Font 10
background=$SYS_THEME_DIR/wallpaper
user-background=false
xft-antialias=true
xft-hintstyle=hintfull
xft-rgba=rgb
panel-position=top
clock-format=%a %d %b  %H:%M
indicators=~host;~spacer;~clock;~spacer;~session;~power
position=50%,center 50%,center
screensaver-timeout=0
EOF

sudo tee /etc/lightdm/lightdm.conf.d/50-color-engine.conf >/dev/null <<EOF
[Seat:*]
display-setup-script=/usr/bin/setxkbmap -option caps:swapescape
EOF

# The greeter runs as the 'lightdm' user and cannot see ~/.local/share/fonts
# (the old JetBrainsMono copy is removed: Iosevka replaced it)
sudo rm -rf /usr/local/share/fonts/JetBrainsMono
if [ -d "$FONT_DIR" ] && [ ! -d "$SYS_FONT_DIR" ]; then
    echo "==> Installing Iosevka Nerd Font system-wide..."
    sudo mkdir -p "$SYS_FONT_DIR"
    sudo cp -rf "$FONT_DIR/"* "$SYS_FONT_DIR/"
    sudo chmod -R a+rX "$SYS_FONT_DIR"
    sudo fc-cache -f >/dev/null
fi

# Re-apply the active palette (falls back to Dracula) so the system theme gets populated
echo "==> Syncing active Color Engine palette to the lock screen..."
THEME_FILE="$CACHE_DIR/current.theme"
[ -f "$THEME_FILE" ] || THEME_FILE="$DOTFILES_DIR/themes/dracula.theme"
# shellcheck disable=SC1090
source "$THEME_FILE"
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$bg" "$fg" "$accent"

echo "[OK] Lock screen now follows the Color Engine. Test it with: lock"
