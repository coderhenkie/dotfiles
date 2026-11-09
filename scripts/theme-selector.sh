#!/usr/bin/env bash

THEME_DIR="$HOME/dotfiles/themes"
CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

# 1. Open Rofi zodat jij een thema kunt kiezen met de pijltjes
THEME_NAME=$(ls "$THEME_DIR" | rofi -dmenu -i -p "🎨 Thema")

# Als je op ESC drukt, stop het script
if [ -z "$THEME_NAME" ]; then
    exit 0
fi

# 2. Laad de 3 kleurcodes ($bg, $fg, $accent) in het geheugen
source "$THEME_DIR/$THEME_NAME"

# 3. Genereer het bestand voor Polybar
cat <<EOF > "$CACHE_DIR/polybar.ini"
[colors]
background = $bg
foreground = $fg
primary = $accent
EOF

# 4. Genereer het bestand voor Kitty
cat <<EOF > "$CACHE_DIR/kitty.conf"
background $bg
foreground $fg
cursor $accent
selection_background $accent
color2 $accent
EOF

# 5. Genereer het bestand voor i3 (Randkleuren)
cat <<EOF > "$CACHE_DIR/i3.conf"
set \$bg $bg
set \$fg $fg
set \$accent $accent

# Format: focused <border> <background> <text> <indicator> <child_border>
client.focused \$accent \$accent \$bg \$accent \$accent
EOF

# 5.5 Genereer het bestand voor Rofi
cat <<EOF > "$CACHE_DIR/rofi.rasi"
* {
bg: $bg;
fg: $fg;
accent: $accent;
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

# --- Plugin Vervangers ---
# Dark Reader: Forceer donkere modus op alle websites
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = "dark"

# Ghostery: Zet de Brave ad- en trackerblocker aan
c.content.blocking.enabled = True
c.content.blocking.method = "both"
EOF

# Vertel Qutebrowser om direct te updaten
if pgrep -x "qutebrowser" > /dev/null; then
    qutebrowser ":config-source" &
fi

# 6. Herstart de interface om kleuren toe te passen
i3-msg restart
