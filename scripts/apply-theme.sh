#!/usr/bin/env bash

set -eu

BG="${1:-}"
FG="${2:-}"
ACCENT="${3:-}"
MODE="${4:-reload}"

if [ -z "$BG" ] || [ -z "$FG" ] || [ -z "$ACCENT" ]; then
    echo "Gebruik: $0 <BG> <FG> <ACCENT> [--no-reload]" >&2
    exit 1
fi

CACHE_DIR="$HOME/.cache/theme"
mkdir -p "$CACHE_DIR"

# 1. Polybar
cat <<EOF > "$CACHE_DIR/polybar.ini"
[colors]
background = $BG
foreground = $FG
primary = $ACCENT
EOF

# 2. Kitty
cat <<EOF > "$CACHE_DIR/kitty.conf"
background $BG
foreground $FG
cursor $ACCENT
selection_background $ACCENT
color2 $ACCENT
EOF

# 3. i3 (Randkleuren)
cat <<EOF > "$CACHE_DIR/i3.conf"
set \$bg $BG
set \$fg $FG
set \$accent $ACCENT

# Format: focused <border> <background> <text> <indicator> <child_border>
client.focused \$accent \$accent \$bg \$accent \$accent
EOF

# 4. Rofi
cat <<EOF > "$CACHE_DIR/rofi.rasi"
* {
    bg: $BG;
    fg: $FG;
    accent: $ACCENT;
    background-color: @bg;
    text-color: @fg;
}
EOF

# 5. Qutebrowser
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

# Dark Reader & Adblocker
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = "dark"
c.content.blocking.enabled = True
c.content.blocking.method = "both"
EOF

# 6. Thunar / GTK3 CSS
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

# 7. Firefox Rice (userChrome.css)
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

# 8. Neovim Color Engine (nvim.lua)
cat <<EOF > "$CACHE_DIR/nvim.lua"
-- Gegenereerd door apply-theme.sh
local bg = "$BG"
local fg = "$FG"
local accent = "$ACCENT"

local function hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber(hex:sub(1, 2), 16) or 0,
           tonumber(hex:sub(3, 4), 16) or 0,
           tonumber(hex:sub(5, 6), 16) or 0
end

local function blend(c1, c2, wt)
    local r1, g1, b1 = hex_to_rgb(c1)
    local r2, g2, b2 = hex_to_rgb(c2)
    local r = math.floor(r1 * (1 - wt) + r2 * wt + 0.5)
    local g = math.floor(g1 * (1 - wt) + g2 * wt + 0.5)
    local b = math.floor(b1 * (1 - wt) + b2 * wt + 0.5)
    return string.format("#%02x%02x%02x", r, g, b)
end

local bg_alt      = blend(bg, fg, 0.08)
local bg_visual   = blend(bg, accent, 0.28)
local fg_muted    = blend(bg, fg, 0.45)
local accent_soft = blend(fg, accent, 0.65)

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
hl("IncSearch",    { fg = bg, bg = accent, bold = true })
hl("StatusLine",   { fg = bg, bg = accent, bold = true })
hl("StatusLineNC", { fg = fg_muted, bg = bg_alt })
hl("WinSeparator", { fg = accent, bg = bg })
hl("VertSplit",    { fg = accent, bg = bg })
hl("Pmenu",        { fg = fg, bg = bg_alt })
hl("PmenuSel",     { fg = bg, bg = accent, bold = true })
hl("TabLine",      { fg = fg_muted, bg = bg_alt })
hl("TabLineSel",   { fg = bg, bg = accent, bold = true })
hl("TabLineFill",  { bg = bg })
hl("Directory",    { fg = accent, bold = true })
hl("Title",        { fg = accent, bold = true })
hl("MatchParen",   { fg = accent, bg = bg_visual, bold = true })
hl("NonText",      { fg = fg_muted })

-- Syntax Highlighting
hl("Comment",      { fg = fg_muted, italic = true })
hl("Constant",     { fg = accent_soft })
hl("String",       { fg = accent_soft })
hl("Character",    { fg = accent_soft })
hl("Number",       { fg = accent })
hl("Boolean",      { fg = accent, bold = true })
hl("Identifier",   { fg = fg })
hl("Function",     { fg = accent, bold = true })
hl("Statement",    { fg = accent, bold = true })
hl("Conditional",  { fg = accent, bold = true })
hl("Repeat",       { fg = accent, bold = true })
hl("Operator",     { fg = accent_soft })
hl("Keyword",      { fg = accent, bold = true })
hl("PreProc",      { fg = accent_soft })
hl("Type",         { fg = accent })
hl("Special",      { fg = accent_soft })
EOF

# 9. Herdr (config.toml via ~/.cache/theme/herdr.toml)
cat <<EOF > "$CACHE_DIR/herdr.toml"
# Gegenereerd door apply-theme.sh (Dotfiles Color Engine)
onboarding = false

[theme]
name = "dracula"

[theme.custom]
sidebar_bg = "$BG"
active_row_bg = "$BG"
selection_bg = "$ACCENT"
panel_bg = "$BG"
text = "$FG"
accent = "$ACCENT"
mauve = "$ACCENT"
EOF

mkdir -p "$HOME/.config/herdr"
ln -sf "$CACHE_DIR/herdr.toml" "$HOME/.config/herdr/config.toml"

# 10. Live herladen (tenzij --no-reload is meegegeven vanuit setup.sh)
if [ "$MODE" != "--no-reload" ]; then
    if pgrep -x "qutebrowser" > /dev/null; then
        qutebrowser ":config-source" &
    fi

    if pgrep -x "herdr" > /dev/null && [ -x "$HOME/.local/bin/herdr" ]; then
        "$HOME/.local/bin/herdr" server reload-config >/dev/null 2>&1 || true
    fi

    bash ~/.config/polybar/launch.sh &
    sleep 0.25
    i3-msg restart
fi
