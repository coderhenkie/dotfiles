#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/dotfiles/wallpapers"
mkdir -p "$WALLPAPER_DIR"

# 1. Kies een wallpaper met Rofi
WALLPAPER=$(ls "$WALLPAPER_DIR" | rofi -dmenu -i -p "Wallpaper")

if [ -z "$WALLPAPER" ]; then
    exit 0
fi

# 2. Stel de wallpaper in en start Pywal (stil, zonder terminal output)
feh --bg-fill "$WALLPAPER_DIR/$WALLPAPER"
"$HOME/.local/bin/wal" -q -i "$WALLPAPER_DIR/$WALLPAPER" -n

# 3. Lees de kleuren die Pywal heeft gegenereerd in ($color0 t/m $color15)
source "$HOME/.cache/wal/colors.sh"

# 4. Pas de kleuren toe via de centrale Color Engine (BG=color0, FG=color15, ACCENT=color4)
bash "$HOME/dotfiles/scripts/apply-theme.sh" "$color0" "$color15" "$color4"
