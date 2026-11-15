# shellcheck shell=bash disable=SC2154  # variables come from apply-theme.sh and the earlier parts
# scripts/theme.d/03-i3.sh: part of apply-theme.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 3. i3 Window Manager (Active & Inactive Border Colors)
# ==========================================
cat <<EOF > "$CACHE_DIR/i3.conf"
font pango:$FONT_UI 10

set \$bg      $BG
set \$bg_alt  $BG_ALT
set \$fg      $FG
set \$muted   $FG_MUTED
set \$accent  $ACCENT
set \$urgent  $ANSI_RED

# Format:               <border>  <background> <text>   <indicator> <child_border>
client.focused          \$accent  \$accent     \$bg     \$accent    \$accent
client.focused_inactive \$bg_alt  \$bg_alt     \$muted  \$bg_alt    \$bg_alt
client.unfocused        \$bg      \$bg         \$muted  \$bg        \$bg
client.urgent           \$urgent  \$urgent     \$bg     \$urgent    \$urgent
client.placeholder      \$bg      \$bg         \$muted  \$bg        \$bg
client.background       \$bg
EOF

