#!/usr/bin/env bash

THEME_DIR="$HOME/dotfiles/themes"

# 1. Open Rofi so you can select a theme with the arrow keys
THEME_NAME=$(ls "$THEME_DIR" | rofi -dmenu -i -p "Theme")

# Exit if Esc is pressed
if [ -z "$THEME_NAME" ]; then
    exit 0
fi

# 2. Load the 3 color variables ($bg, $fg, $accent) into memory
source "$THEME_DIR/$THEME_NAME"

# 3. Apply the colors through the central Color Engine
bash "$HOME/dotfiles/scripts/apply-theme.sh" "$bg" "$fg" "$accent"
