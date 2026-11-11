#!/usr/bin/env bash

set -eu

BG="${1:-}"
FG="${2:-}"
ACCENT="${3:-}"
MODE="${4:-reload}"

if [ -z "$BG" ] || [ -z "$FG" ] || [ -z "$ACCENT" ]; then
    echo "Usage: $0 <BG> <FG> <ACCENT> [--no-reload]" >&2
    exit 1
fi

# ==========================================
# Central Color Calculation (Color Blending)
# ==========================================
# Blend two hex colors (#rrggbb) based on weight (0-100% of color 2)
blend_hex() {
    local c1="${1#\#}"
    local c2="${2#\#}"
    local wt="$3"

    local r1=$((16#${c1:0:2})) g1=$((16#${c1:2:2})) b1=$((16#${c1:4:2}))
    local r2=$((16#${c2:0:2})) g2=$((16#${c2:2:2})) b2=$((16#${c2:4:2}))

    local r=$(( (r1 * (100 - wt) + r2 * wt + 50) / 100 ))
    local g=$(( (g1 * (100 - wt) + g2 * wt + 50) / 100 ))
    local b=$(( (b1 * (100 - wt) + b2 * wt + 50) / 100 ))

    printf "#%02x%02x%02x\n" "$r" "$g" "$b"
}

# Derived shades from BG, FG, and ACCENT
BG_ALT=$(blend_hex "$BG" "$FG" 8)          # Subtle elevated background (bars, floats, odd tabs)
BG_VISUAL=$(blend_hex "$BG" "$ACCENT" 28)  # Selection and highlight background
FG_MUTED=$(blend_hex "$BG" "$FG" 48)       # Muted text, comments & inactive elements
ACCENT_SOFT=$(blend_hex "$FG" "$ACCENT" 65) # Softer variant of the accent color
ACCENT_DIM=$(blend_hex "$BG" "$ACCENT" 75)  # Deeper variant of the accent color

# Harmonic ANSI terminal colors (blended with the active theme)
ANSI_RED=$(blend_hex "#ff5555" "$ACCENT" 20)
ANSI_GREEN=$(blend_hex "#50fa7b" "$ACCENT" 25)
ANSI_YELLOW=$(blend_hex "#f1fa8c" "$ACCENT" 20)
ANSI_CYAN=$(blend_hex "$ACCENT_SOFT" "#8be9fd" 45)

CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

# ==========================================
# 1. Polybar
# ==========================================
cat <<EOF > "$CACHE_DIR/polybar.ini"
[colors]
background = $BG
background-alt = $BG_ALT
foreground = $FG
muted = $FG_MUTED
primary = $ACCENT
secondary = $ACCENT_SOFT
urgent = $ANSI_RED
EOF

# ==========================================
# 2. Kitty Terminal (Full 16-color ANSI palette + Tabs)
# ==========================================
cat <<EOF > "$CACHE_DIR/kitty.conf"
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

# ==========================================
# 3. i3 Window Manager (Active & Inactive Border Colors)
# ==========================================
cat <<EOF > "$CACHE_DIR/i3.conf"
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

# ==========================================
# 4. Rofi
# ==========================================
cat <<EOF > "$CACHE_DIR/rofi.rasi"
* {
    bg:        $BG;
    bg-alt:    $BG_ALT;
    bg-visual: $BG_VISUAL;
    fg:        $FG;
    muted:     $FG_MUTED;
    accent:    $ACCENT;
    background-color: @bg;
    text-color: @fg;
}
EOF

# ==========================================
# 5. Thunar / GTK3 CSS, Thorium Browser & Dynamic Folder Icons
# ==========================================
mkdir -p "$HOME/.config/gtk-3.0"
cat <<EOF > "$HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-application-prefer-dark-theme=1
gtk-icon-theme-name=ColorEngine
EOF

cat <<EOF > "$CACHE_DIR/gtk.css"
@define-color theme_bg_color $BG_ALT;
@define-color theme_fg_color $FG;
@define-color theme_base_color $BG;
@define-color theme_text_color $FG;
@define-color theme_selected_bg_color $ACCENT;
@define-color theme_selected_fg_color $BG;
@define-color theme_unfocused_bg_color $BG_ALT;
@define-color theme_unfocused_text_color $FG_MUTED;
@define-color borders $BG_VISUAL;

/* Color symbolic sidebar icons in Thunar with the accent color */
.sidebar image,
placessidebar image {
    color: $ACCENT;
}

/* GTK3 Headerbar / Toolbar styling for Thorium Browser (GTK+ Theme Mode) */
headerbar,
.titlebar,
menubar,
toolbar {
    background-color: $BG;
    color: $FG;
}

headerbar:backdrop,
.titlebar:backdrop {
    background-color: $BG_ALT;
    color: $FG_MUTED;
}

selection {
    background-color: $ACCENT;
    color: $BG;
}
EOF
ln -sf "$CACHE_DIR/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

# Ensure Thorium Browser is configured to inherit GTK+ theme colors
mkdir -p "$HOME/.config/thorium/Default"
if [ ! -f "$HOME/.config/thorium/Default/Preferences" ]; then
    cat <<EOF > "$HOME/.config/thorium/Default/Preferences"
{
  "browser": {
    "custom_chrome_frame": true,
    "theme": {
      "color_scheme2": 2
    }
  },
  "extensions": {
    "theme": {
      "id": "use_system",
      "system_theme": 1,
      "use_system": true
    }
  }
}
EOF
fi

# Dynamic Icon Theme (ColorEngine) for Thunar folders
ICON_DIR="$HOME/.local/share/icons/ColorEngine"
mkdir -p "$ICON_DIR/scalable/places" "$ICON_DIR/scalable/status" "$ICON_DIR/16x16/places" "$ICON_DIR/16x16/status"

cat <<EOF > "$ICON_DIR/index.theme"
[Icon Theme]
Name=ColorEngine
Comment=Dynamic Color Engine Folder Icons (inherits from Adwaita)
Inherits=Adwaita,AdwaitaLegacy,hicolor
Directories=scalable/places,scalable/status,16x16/places,16x16/status

[scalable/places]
Context=Places
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[scalable/status]
Context=Status
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[16x16/places]
Context=Places
Size=16
MinSize=8
MaxSize=512
Type=Scalable

[16x16/status]
Context=Status
Size=16
MinSize=8
MaxSize=512
Type=Scalable
EOF

# Shades for the folder back, base, front, and highlight
FOLDER_BACK=$(blend_hex "$BG" "$ACCENT" 65)
FOLDER_BASE="$ACCENT_DIM"
FOLDER_FRONT="$ACCENT"
FOLDER_SHINE=$(blend_hex "$FG" "$ACCENT" 45)

if [ -d "/usr/share/icons/Adwaita/scalable/places" ]; then
    for svg in /usr/share/icons/Adwaita/scalable/places/folder*.svg \
               /usr/share/icons/Adwaita/scalable/places/user-home.svg \
               /usr/share/icons/Adwaita/scalable/places/user-desktop.svg \
               /usr/share/icons/Adwaita/scalable/places/user-bookmarks.svg; do
        [ -f "$svg" ] || continue
        fname=$(basename "$svg")
        sed -e "s/#438de6/$FOLDER_BACK/gI" \
            -e "s/#62a0ea/$FOLDER_BASE/gI" \
            -e "s/#a4caee/$FOLDER_FRONT/gI" \
            -e "s/#afd4ff/$FOLDER_SHINE/gI" \
            -e "s/#c0d5ea/$ACCENT_SOFT/gI" \
            "$svg" > "$ICON_DIR/scalable/places/$fname"
        ln -sf "../../scalable/places/$fname" "$ICON_DIR/16x16/places/$fname"
    done
fi

if [ -f "/usr/share/icons/Adwaita/scalable/status/folder-open.svg" ]; then
    sed -e "s/#438de6/$FOLDER_BACK/gI" \
        -e "s/#62a0ea/$FOLDER_BASE/gI" \
        -e "s/#a4caee/$FOLDER_FRONT/gI" \
        -e "s/#afd4ff/$FOLDER_SHINE/gI" \
        -e "s/#c0d5ea/$ACCENT_SOFT/gI" \
        "/usr/share/icons/Adwaita/scalable/status/folder-open.svg" > "$ICON_DIR/scalable/status/folder-open.svg"
    ln -sf "../../scalable/status/folder-open.svg" "$ICON_DIR/16x16/status/folder-open.svg"
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$ICON_DIR" >/dev/null 2>&1 || true
fi

# ==========================================
# 6. Neovim Color Engine (nvim.lua)
# ==========================================
cat <<EOF > "$CACHE_DIR/nvim.lua"
-- Generated by apply-theme.sh
local bg          = "$BG"
local bg_alt      = "$BG_ALT"
local bg_visual   = "$BG_VISUAL"
local fg          = "$FG"
local fg_muted    = "$FG_MUTED"
local accent      = "$ACCENT"
local accent_soft = "$ACCENT_SOFT"
local ansi_red    = "$ANSI_RED"
local ansi_green  = "$ANSI_GREEN"
local ansi_yellow = "$ANSI_YELLOW"

vim.cmd("highlight clear")
vim.o.background = "dark"
vim.g.colors_name = "color_engine"

local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
end

-- Editor & UI
hl("Normal",       { fg = fg, bg = bg })
hl("NormalNC",     { fg = fg, bg = bg })
hl("NormalFloat",  { fg = fg, bg = bg_alt })
hl("FloatBorder",  { fg = accent, bg = bg_alt })
hl("CursorLine",   { bg = bg_alt })
hl("CursorLineNr", { fg = accent, bg = bg_alt, bold = true })
hl("LineNr",       { fg = fg_muted, bg = bg })
hl("SignColumn",   { fg = fg_muted, bg = bg })
hl("Visual",       { bg = bg_visual })
hl("Search",       { fg = bg, bg = accent, bold = true })
hl("IncSearch",    { fg = bg, bg = accent_soft, bold = true })
hl("StatusLine",   { fg = bg, bg = accent, bold = true })
hl("StatusLineNC", { fg = fg_muted, bg = bg_alt })
hl("WinSeparator", { fg = bg_visual, bg = bg })
hl("VertSplit",    { fg = bg_visual, bg = bg })
hl("Pmenu",        { fg = fg, bg = bg_alt })
hl("PmenuSel",     { fg = bg, bg = accent, bold = true })
hl("TabLine",      { fg = fg_muted, bg = bg_alt })
hl("TabLineSel",   { fg = bg, bg = accent, bold = true })
hl("TabLineFill",  { bg = bg })
hl("Directory",    { fg = accent, bold = true })
hl("Title",        { fg = accent, bold = true })
hl("MatchParen",   { fg = accent, bg = bg_visual, bold = true })
hl("NonText",      { fg = fg_muted })
hl("DiagnosticError", { fg = ansi_red })
hl("DiagnosticWarn",  { fg = ansi_yellow })
hl("DiagnosticInfo",  { fg = accent_soft })
hl("DiagnosticHint",  { fg = ansi_green })

-- Syntax Highlighting
hl("Comment",      { fg = fg_muted, italic = true })
hl("Constant",     { fg = accent_soft })
hl("String",       { fg = ansi_green })
hl("Character",    { fg = ansi_green })
hl("Number",       { fg = accent_soft })
hl("Boolean",      { fg = accent, bold = true })
hl("Identifier",   { fg = fg })
hl("Function",     { fg = accent, bold = true })
hl("Statement",    { fg = accent, bold = true })
hl("Conditional",  { fg = accent, bold = true })
hl("Repeat",       { fg = accent, bold = true })
hl("Operator",     { fg = accent_soft })
hl("Keyword",      { fg = accent, bold = true })
hl("PreProc",      { fg = accent_soft })
hl("Type",         { fg = ansi_yellow })
hl("Special",      { fg = accent_soft })
EOF

# ==========================================
# 7. Herdr (config.toml via ~/.cache/theme/herdr.toml)
# ==========================================
cat <<EOF > "$CACHE_DIR/herdr.toml"
# Generated by apply-theme.sh (Dotfiles Color Engine)
onboarding = false

[theme]
name = "dracula"

[theme.custom]
sidebar_bg = "$BG"
active_row_bg = "$BG_ALT"
selection_bg = "$BG_VISUAL"
panel_bg = "$BG"
surface_dim = "$FG_MUTED"
text = "$FG"
accent = "$ACCENT"
mauve = "$ACCENT_SOFT"
red = "$ANSI_RED"
green = "$ANSI_GREEN"
yellow = "$ANSI_YELLOW"
EOF

mkdir -p "$HOME/.config/herdr"
ln -sf "$CACHE_DIR/herdr.toml" "$HOME/.config/herdr/config.toml"

# ==========================================
# 8. btop Resource Monitor (btop.theme via ~/.config/btop/themes/color_engine.theme)
# ==========================================
cat <<EOF > "$CACHE_DIR/btop.theme"
# Generated by apply-theme.sh (Dotfiles Color Engine)
theme[main_bg]="$BG"
theme[main_fg]="$FG"
theme[title]="$ACCENT"
theme[hi_fg]="$ACCENT_SOFT"
theme[selected_bg]="$BG_VISUAL"
theme[selected_fg]="$FG"
theme[inactive_fg]="$FG_MUTED"
theme[graph_text]="$FG"
theme[meter_bg]="$BG_ALT"
theme[proc_misc]="$ACCENT_SOFT"
theme[cpu_box]="$ACCENT"
theme[mem_box]="$ACCENT_SOFT"
theme[net_box]="$ANSI_CYAN"
theme[proc_box]="$ACCENT"
theme[div_line]="$BG_VISUAL"
theme[temp_start]="$ANSI_GREEN"
theme[temp_mid]="$ANSI_YELLOW"
theme[temp_end]="$ANSI_RED"
theme[cpu_start]="$ACCENT_DIM"
theme[cpu_mid]="$ACCENT"
theme[cpu_end]="$ACCENT_SOFT"
theme[free_start]="$ACCENT_DIM"
theme[free_mid]="$ACCENT_SOFT"
theme[free_end]="$ANSI_GREEN"
theme[cached_start]="$ACCENT_DIM"
theme[cached_mid]="$ACCENT"
theme[cached_end]="$ACCENT_SOFT"
theme[available_start]="$ACCENT_DIM"
theme[available_mid]="$ACCENT"
theme[available_end]="$ANSI_CYAN"
theme[used_start]="$ANSI_GREEN"
theme[used_mid]="$ANSI_YELLOW"
theme[used_end]="$ANSI_RED"
theme[download_start]="$ACCENT_DIM"
theme[download_mid]="$ACCENT"
theme[download_end]="$ANSI_CYAN"
theme[upload_start]="$ACCENT_DIM"
theme[upload_mid]="$ACCENT"
theme[upload_end]="$ACCENT_SOFT"
theme[process_start]="$ACCENT_DIM"
theme[process_mid]="$ACCENT"
theme[process_end]="$ACCENT_SOFT"
EOF

mkdir -p "$HOME/.config/btop/themes"
ln -sf "$CACHE_DIR/btop.theme" "$HOME/.config/btop/themes/color_engine.theme"
if [ -f "$HOME/.config/btop/btop.conf" ]; then
    sed -i 's|^color_theme = .*|color_theme = "color_engine"|' "$HOME/.config/btop/btop.conf"
fi

# ==========================================
# 9. Live Reload (unless --no-reload is passed from setup.sh)
# ==========================================
if [ "$MODE" != "--no-reload" ]; then
    # Kitty supports live config reload via SIGUSR1
    if pgrep -x "kitty" > /dev/null; then
        pkill -USR1 -x kitty || true
    fi

    # btop supports live theme/config reload via SIGUSR2
    if pgrep -x "btop" > /dev/null; then
        pkill -USR2 -x btop || true
    fi

    if pgrep -x "herdr" > /dev/null && [ -x "$HOME/.local/bin/herdr" ]; then
        "$HOME/.local/bin/herdr" server reload-config >/dev/null 2>&1 || true
    fi

    export DISPLAY="${DISPLAY:-:0}"
    if [ -z "${I3SOCK:-}" ]; then
        I3SOCK=$(ls "/run/user/$(id -u)/i3/"ipc-socket.* 2>/dev/null | head -n 1 || true)
        [ -n "$I3SOCK" ] && export I3SOCK
    fi

    if i3-msg -t get_version >/dev/null 2>&1; then
        i3-msg restart >/dev/null 2>&1 || true
    fi
fi
