#!/usr/bin/env bash
# ==========================================
# Rofi entries for the dotfiles tools + hidden clutter
# ==========================================
# Writes a .desktop file for every dotfiles tool into ~/.local/share/applications,
# so they can be found in Rofi's app launcher ($mod+space) by name or keyword
# (e.g. "font", "lettertype", "kleuren"), next to their hotkeys. Icons are drawn by
# scripts/rofi-icons.sh (glyphs in rofi/app-icons.conf, names colorengine-*).
# Also hides launcher entries that are only noise in Rofi (see HIDE below).
# Safe to re-run; called by setup.sh.
#
# Usage: desktop-entries.sh [-h|--help]

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

APPS_DIR="$HOME/.local/share/applications"
SCRIPTS="$DOTFILES_DIR/scripts"
mkdir -p "$APPS_DIR"

# id | Name | Comment (incl. hotkey) | command | search keywords (English + Dutch)
TOOLS=(
    "font-picker|Font Picker|Change the desktop font (\$mod+Shift+f)|$SCRIPTS/menu-font.sh|font;fonts;typeface;lettertype;letters;"
    "theme-selector|Theme Selector|Pick a preset colour theme (\$mod+Shift+w)|$SCRIPTS/menu-theme.sh|theme;colors;colours;kleuren;thema;"
    "wallpaper-theme|Wallpaper Theme|Pick a wallpaper and generate matching colours (\$mod+t)|$SCRIPTS/menu-wallpaper.sh|wallpaper;background;achtergrond;pywal;theme;kleuren;"
    "hotkeys|Hotkey Menu|View and rebind hotkeys (\$mod+m)|$SCRIPTS/menu-hotkeys.sh|hotkeys;shortcuts;keybindings;sneltoetsen;toetsen;"
    "modkey|Switch Mod Key|Toggle the mod key between Alt and Super|$SCRIPTS/toggle-modkey.sh|mod;alt;super;windows;"
    "clipboard|Clipboard History|Copy an earlier clipboard entry again (\$mod+c)|$SCRIPTS/menu-clipboard.sh menu|clipboard;history;klembord;geschiedenis;paste;"
    "calculator|Calculator|Calculate, convert units and currencies (\$mod+equal)|$SCRIPTS/menu-calc.sh|calculator;calc;math;rekenmachine;rekenen;"
    "emoji|Emoji Picker|Type or copy an emoji (\$mod+Shift+period)|$SCRIPTS/menu-emoji.sh|emoji;smiley;emoticon;"
    "screenshot|Screenshot|Select an area: saved to ~/Pictures and copied (Ctrl+Shift+s)|$SCRIPTS/screenshot.sh|screenshot;capture;schermafbeelding;printscreen;"
    "notifications|Notifications|Silent mode, history and muted apps (\$mod+Shift+n)|$SCRIPTS/menu-notifications.sh menu|notifications;silent;mute;meldingen;stil;"
    "power|Power Menu|Lock, suspend, log out, reboot or shut down (\$mod+Shift+e)|$SCRIPTS/menu-power.sh|power;shutdown;reboot;logout;suspend;afsluiten;herstarten;uitloggen;"
    "lock|Lock Screen|Lock the screen (\$mod+Shift+x)|$SCRIPTS/lock.sh|lock;vergrendelen;"
    "audio-fix|Bluetooth Audio Fix|Headphones back to high quality A2DP sound (\$mod+Shift+a)|$SCRIPTS/bt-audio-fix.sh|audio;bluetooth;headphones;headset;a2dp;sound;profile;koptelefoon;geluid;geluidsprofiel;oortjes;"
    "monitors|Screens|Mirror or extend screens, choose left / right (\$mod+p)|$SCRIPTS/menu-monitors.sh|monitor;monitors;screens;display;layout;mirror;extend;spiegelen;uitbreiden;beeldscherm;scherm;schermen;"
)

for tool in "${TOOLS[@]}"; do
    IFS='|' read -r id name comment cmd keywords <<< "$tool"
    cat > "$APPS_DIR/colorengine-$id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$cmd
Icon=colorengine-$id
Terminal=false
Categories=Settings;X-ColorEngine;
Keywords=$keywords
EOF
done

# Entries that are only noise in Rofi: a local copy with NoDisplay=true overrides the system one
# (the packages stay installed: ImageMagick is needed by Pywal).
HIDE=(
    display-im7.q16.desktop   # ImageMagick's old image editor GUI
)
for entry in "${HIDE[@]}"; do
    src="/usr/share/applications/$entry"
    [ -f "$src" ] || continue
    sed '/^NoDisplay=/d; s/^\[Desktop Entry\]$/[Desktop Entry]\nNoDisplay=true/' "$src" > "$APPS_DIR/$entry"
done

if have update-desktop-database; then
    update-desktop-database -q "$APPS_DIR" 2>/dev/null || true
fi
ok "Rofi entries for ${#TOOLS[@]} dotfiles tools written; ${#HIDE[@]} entries hidden."
