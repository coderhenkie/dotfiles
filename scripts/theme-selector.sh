#!/usr/bin/env bash

THEME_DIR="$HOME/dotfiles/themes"

# 1. Open Rofi zodat jij een thema kunt kiezen met de pijltjes
THEME_NAME=$(ls "$THEME_DIR" | rofi -dmenu -i -p "Thema")

# Als je op ESC drukt, stop het script
if [ -z "$THEME_NAME" ]; then
    exit 0
fi

# 2. Laad de 3 kleurcodes ($bg, $fg, $accent) in het geheugen
source "$THEME_DIR/$THEME_NAME"

# 3. Pas de kleuren toe via de centrale Color Engine
bash "$HOME/dotfiles/scripts/apply-theme.sh" "$bg" "$fg" "$accent"
