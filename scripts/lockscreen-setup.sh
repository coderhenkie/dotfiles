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
SYS_FONT_DIR="/usr/local/share/fonts/ColorEngine"   # font modules (scripts/lib/fonts.sh)

echo "==> Provisioning LightDM ColorEngine theme directories..."
sudo mkdir -p "$SYS_THEME_DIR/gtk-3.0" "$SYS_ICON_DIR" "$SYS_FONT_DIR" /etc/lightdm/lightdm.conf.d
# User-owned, world-readable: apply-theme.sh / font-picker.sh update them without sudo,
# and the LightDM greeter (user 'lightdm') can read them
sudo chown -R "$USER:$USER" "$SYS_THEME_DIR" "$SYS_ICON_DIR" "$SYS_FONT_DIR"
sudo chmod -R a+rX,u+w "$SYS_THEME_DIR" "$SYS_ICON_DIR" "$SYS_FONT_DIR"

echo "==> Writing LightDM GTK greeter configuration..."
sudo tee /etc/lightdm/lightdm-gtk-greeter.conf >/dev/null <<EOF
[greeter]
theme-name=ColorEngine
icon-theme-name=ColorEngine
font-name=Sans 10
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

# Fonts used to live in per-font system dirs (root-owned); they now live in the user-owned
# $SYS_FONT_DIR/<module> (installed by scripts/lib/fonts.sh), which the greeter can read too.
sudo rm -rf /usr/local/share/fonts/JetBrainsMono /usr/local/share/fonts/Iosevka
sudo fc-cache -f >/dev/null 2>&1 || true

# Re-apply the active palette (falls back to Dracula) so the system theme gets populated
echo "==> Syncing active Color Engine palette to the lock screen..."
THEME_FILE="$CACHE_DIR/current.theme"
[ -f "$THEME_FILE" ] || THEME_FILE="$DOTFILES_DIR/themes/dracula.theme"
# shellcheck disable=SC1090
source "$THEME_FILE"
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$bg" "$fg" "$accent"

echo "[OK] Lock screen now follows the Color Engine. Test it with: lock"
