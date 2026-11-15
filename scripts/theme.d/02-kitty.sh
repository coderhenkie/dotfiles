# shellcheck shell=bash disable=SC2154  # variables come from apply-theme.sh and the earlier parts
# scripts/theme.d/02-kitty.sh: part of apply-theme.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 2. Kitty Terminal (Full 16-color ANSI palette + Tabs)
# ==========================================
cat <<EOF > "$CACHE_DIR/kitty.conf"
# Font (Mono variant: every icon exactly one cell wide)
font_family $FONT_MONO

# Base & Cursor
background            $BG
foreground            $FG
cursor                $ACCENT
cursor_text_color     $BG
selection_background  $BG_VISUAL
selection_foreground  $FG
url_color             $ACCENT_SOFT

# Window Borders & Tabs
active_border_color   $ACCENT
inactive_border_color $BG_ALT
active_tab_background   $ACCENT
active_tab_foreground   $BG
inactive_tab_background $BG_ALT
inactive_tab_foreground $FG_MUTED

# Black / Gray (0 & 8)
color0  $BG
color8  $FG_MUTED

# Red (1 & 9)
color1  $ANSI_RED
color9  $ANSI_RED

# Green (2 & 10)
color2  $ANSI_GREEN
color10 $ANSI_GREEN

# Yellow (3 & 11)
color3  $ANSI_YELLOW
color11 $ANSI_YELLOW

# Blue / Primary Accent (4 & 12)
color4  $ACCENT_DIM
color12 $ACCENT

# Magenta / Secondary Accent (5 & 13)
color5  $ACCENT
color13 $ACCENT_SOFT

# Cyan (6 & 14)
color6  $ANSI_CYAN
color14 $ACCENT_SOFT

# White / Foreground (7 & 15)
color7  $FG
color15 $FG
EOF

