#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/dotfiles/wallpapers"
mkdir -p "$WALLPAPER_DIR"

# 1. Select a wallpaper via Rofi
WALLPAPER=$(ls "$WALLPAPER_DIR" | rofi -dmenu -i -p "Wallpaper")

if [ -z "$WALLPAPER" ]; then
    exit 0
fi

# 2. Set the wallpaper with feh and run Pywal (quietly, without terminal output)
feh --bg-fill "$WALLPAPER_DIR/$WALLPAPER"
"$HOME/.local/bin/wal" -q -i "$WALLPAPER_DIR/$WALLPAPER" -n

# 3. Source the generated Pywal colors ($color0 through $color15)
source "$HOME/.cache/wal/colors.sh"

# 4. Apply the colors through the central Color Engine (BG=color0, FG=color15, ACCENT=color4)
bash "$HOME/dotfiles/scripts/apply-theme.sh" "$color0" "$color15" "$color4"
