#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/dotfiles/wallpapers"
CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$WALLPAPER_DIR"

# 1. Kies een wallpaper met Rofi
WALLPAPER=$(ls "$WALLPAPER_DIR" | rofi -dmenu -i -p "🖼️ Wallpaper")

if [ -z "$WALLPAPER" ]; then
    exit 0
fi

# 2. Stel de wallpaper in en start Pywal (stil, zonder terminal output)
feh --bg-fill "$WALLPAPER_DIR/$WALLPAPER"
$HOME/.local/bin/wal -q -i "$WALLPAPER_DIR/$WALLPAPER" -n

# 3. Lees de kleuren die Pywal heeft gegenereerd in
source "$HOME/.cache/wal/colors.sh"

# Pywal maakt 16 kleuren ($color0 t/m $color15).
# We koppelen deze aan jouw Color Engine (BG, FG, ACCENT)
BG=$color0
FG=$color15
ACCENT=$color4

# 4. Genereer het Polybar bestand
cat <<EOF > "$CACHE_DIR/polybar.ini"
[colors]
background = $BG
foreground = $FG
primary = $ACCENT
EOF

# 5. Genereer het Kitty bestand
cat <<EOF > "$CACHE_DIR/kitty.conf"
background $BG
foreground $FG
cursor $ACCENT
selection_background $ACCENT
color2 $ACCENT
EOF

# 6. Genereer het i3 bestand
cat <<EOF > "$CACHE_DIR/i3.conf"
set \$bg $BG
set \$fg $FG
set \$accent $ACCENT
client.focused \$accent \$accent \$bg \$accent \$accent
EOF

# 7. Genereer het Rofi bestand
cat <<EOF > "$CACHE_DIR/rofi.rasi"
* {
bg: $BG;
fg: $FG;
accent: $ACCENT;
background-color: @bg;
text-color: @fg;
}
EOF

# Genereer het Qutebrowser bestand
cat <<EOF > "$CACHE_DIR/qutebrowser.py"
c.colors.statusbar.normal.bg = "$BG"
c.colors.statusbar.normal.fg = "$FG"
c.colors.tabs.even.bg = "$BG"
c.colors.tabs.even.fg = "$FG"
c.colors.tabs.odd.bg = "$BG"
c.colors.tabs.odd.fg = "$FG"
c.colors.tabs.selected.even.bg = "$ACCENT"
c.colors.tabs.selected.even.fg = "$BG"
c.colors.tabs.selected.odd.bg = "$ACCENT"
c.colors.tabs.selected.odd.fg = "$BG"
EOF

# 8. Herstart de interface om alles toe te passen
bash ~/.config/polybar/launch.sh &
sleep 0.25
i3-msg restart
