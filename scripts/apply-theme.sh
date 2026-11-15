#!/usr/bin/env bash
# ==========================================
# Color Engine: generate every themed config from three colors
# ==========================================
# Derives a full palette from background, foreground and accent and writes the configs for
# Polybar, Kitty, i3, Rofi, GTK/LightDM, Neovim, Herdr, btop, Dunst, Zathura, Starship,
# Obsidian, Spotify (Spicetify) and Dark Reader into ~/.cache/theme, then live-reloads them.
#
# Usage: apply-theme.sh [<BG> <FG> <ACCENT>] [--no-reload] [-h|--help]
#   colors        #rrggbb; without colors the active theme is re-applied
#                 (~/.cache/theme/current.theme, falling back to Dracula)
#   --no-reload   only write the files; don't signal Kitty/btop/Dunst/Herdr or restart i3

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/bootstrap.sh
source "$SCRIPT_DIR/lib/bootstrap.sh"

RELOAD=1
COLORS=()
for arg in "$@"; do
    case "$arg" in
        -h|--help)   help_from_header; exit 0 ;;
        --no-reload) RELOAD=0 ;;
        -*)          die "Unknown option: $arg (see --help)" ;;
        *)           COLORS+=("$arg") ;;
    esac
done

case "${#COLORS[@]}" in
    0)
        # shellcheck disable=SC2119  # theme_load without a file = the active theme
        theme_load || die "No colors given and no valid active theme to re-apply."
        # shellcheck disable=SC2154  # bg/fg/accent are set by theme_load
        COLORS=("$bg" "$fg" "$accent") ;;
    3)  ;;
    *)  die "Give all three colors: apply-theme.sh <BG> <FG> <ACCENT> (see --help)" ;;
esac
BG="${COLORS[0]}" FG="${COLORS[1]}" ACCENT="${COLORS[2]}"
for c in "$BG" "$FG" "$ACCENT"; do
    is_hex_color "$c" || die "Not a #rrggbb color: '$c'"
done

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

CACHE_DIR="$THEME_CACHE"
mkdir -p "$CACHE_DIR"

# Active font module (scripts/menu-font.sh, $mod+Shift+f): put into every generated config below
# shellcheck source-path=SCRIPTDIR source=lib/fonts.sh
source "$SCRIPT_DIR/lib/fonts.sh"
font_load "$(font_active)"
FONT_UI="$FONT_FAMILY"         # UI: Polybar, i3, Rofi, dunst, GTK, LightDM, Zathura, Spotify, web pages
FONT_MONO="$FONT_FAMILY_MONO"  # Kitty

# Persist the active palette so other scripts (lockscreen-setup.sh) can re-apply it
printf 'bg=%s\nfg=%s\naccent=%s\n' "$BG" "$FG" "$ACCENT" > "$CACHE_DIR/current.theme"


# ==========================================
# Color Engine steps: scripts/theme.d/NN-*.sh, sourced in this order (same shell, same variables and helpers)
# ==========================================
# shellcheck source-path=SCRIPTDIR source=theme.d/01-polybar.sh
source "$SCRIPT_DIR/theme.d/01-polybar.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/02-kitty.sh
source "$SCRIPT_DIR/theme.d/02-kitty.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/03-i3.sh
source "$SCRIPT_DIR/theme.d/03-i3.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/04-rofi.sh
source "$SCRIPT_DIR/theme.d/04-rofi.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/05-gtk-lightdm-icons.sh
source "$SCRIPT_DIR/theme.d/05-gtk-lightdm-icons.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/06-neovim.sh
source "$SCRIPT_DIR/theme.d/06-neovim.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/07-herdr.sh
source "$SCRIPT_DIR/theme.d/07-herdr.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/08-btop.sh
source "$SCRIPT_DIR/theme.d/08-btop.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/09-dunst.sh
source "$SCRIPT_DIR/theme.d/09-dunst.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/10-zathura.sh
source "$SCRIPT_DIR/theme.d/10-zathura.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/11-starship.sh
source "$SCRIPT_DIR/theme.d/11-starship.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/12-obsidian.sh
source "$SCRIPT_DIR/theme.d/12-obsidian.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/13-spotify.sh
source "$SCRIPT_DIR/theme.d/13-spotify.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/14-darkreader.sh
source "$SCRIPT_DIR/theme.d/14-darkreader.sh"
# shellcheck source-path=SCRIPTDIR source=theme.d/15-reload.sh
source "$SCRIPT_DIR/theme.d/15-reload.sh"
