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

# FIX: Map kleine letters naar de verwachte hoofdletters voor de generatie
BG=$bg
FG=$fg
ACCENT=$accent

# 3. Genereer het bestand voor Polybar
cat <<EOF > "$CACHE_DIR/polybar.ini"
[colors]
background = $BG
foreground = $FG
primary = $ACCENT
EOF

# 4. Genereer het bestand voor Kitty
cat <<EOF > "$CACHE_DIR/kitty.conf"
background $BG
foreground $FG
cursor $ACCENT
selection_background $ACCENT
color2 $ACCENT
EOF

# 5. Genereer het bestand voor i3 (Randkleuren)
cat <<EOF > "$CACHE_DIR/i3.conf"
set \$bg $BG
set \$fg $FG
set \$accent $ACCENT

# Format: focused <border> <background> <text> <indicator> <child_border>
client.focused \$accent \$accent \$bg \$accent \$accent
EOF

# 5.5 Genereer het bestand voor Rofi
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

# 7.6 Genereer de Thunar / GTK3 CSS
cat <<EOF > "$CACHE_DIR/gtk.css"
@define-color theme_bg_color $BG;
@define-color theme_fg_color $FG;
@define-color theme_base_color $BG;
@define-color theme_text_color $FG;
@define-color theme_selected_bg_color $ACCENT;
@define-color theme_selected_fg_color $BG;
@define-color theme_unfocused_bg_color $BG;
@define-color theme_unfocused_text_color $FG;
EOF

# FIREFOX RICE
cat <<EOF > "$CACHE_DIR/userChrome.css"
/* Firefox Color Engine Rice */
:root {
  --bg-color: $BG !important;
  --fg-color: $FG !important;
  --accent-color: $ACCENT !important;
  --toolbar-bgcolor: $BG !important;
  --toolbar-color: $FG !important;
  --lwt-accent-color: $BG !important;
  --lwt-text-color: $FG !important;
  --tab-selected-bgcolor: $ACCENT !important;
  --tab-selected-textcolor: $BG !important;
}

#navigator-toolbox {
    background-color: var(--bg-color) !important;
    border: none !important;
}

#urlbar-background {
    background-color: var(--bg-color) !important;
    border: 1px solid var(--accent-color) !important;
}

.tab-background {
    background-color: var(--bg-color) !important;
    color: var(--fg-color) !important;
}

.tab-background[selected="true"] {
    background-color: var(--accent-color) !important;
}
EOF

# 6. Herstart de interface om kleuren toe te passen
bash ~/.config/polybar/launch.sh &
sleep 0.25
i3-msg restart
