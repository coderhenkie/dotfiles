# shellcheck shell=bash disable=SC2154  # variables come from apply-theme.sh and the earlier parts
# scripts/theme.d/01-polybar.sh: part of apply-theme.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 1. Polybar
# ==========================================
cat <<EOF > "$CACHE_DIR/polybar.ini"
[fonts]
main = "$FONT_UI:size=10.5;2"
bold = "$FONT_UI:style=Bold:size=10.5;2"

[colors]
background = $BG
background-alt = $BG_ALT
foreground = $FG
muted = $FG_MUTED
primary = $ACCENT
secondary = $ACCENT_SOFT
urgent = $ANSI_RED
EOF

