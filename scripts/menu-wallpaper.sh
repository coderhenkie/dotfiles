#!/usr/bin/env bash
# ==========================================
# Wallpaper & Pywal Theme Picker (Rofi)
# ==========================================
# Selects a wallpaper from <dotfiles>/wallpapers/, sets it with feh, generates a palette
# via Pywal, parses the generated colors as data (without sourcing), and applies them
# through apply-theme.sh.
#
# Usage: menu-wallpaper.sh [-h|--help]

# No set -e: rofi returns non-zero when the user cancels with Esc.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need rofi feh

WALLPAPER_DIR="$DOTFILES_DIR/wallpapers"
mkdir -p "$WALLPAPER_DIR"

mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 1 -xtype f -printf '%f\n' 2>/dev/null | sort)
[ "${#wallpapers[@]}" -gt 0 ] || exit 0

# 1. Select a wallpaper via Rofi (-no-custom prevents arbitrary paths)
WALLPAPER=$(printf '%s\n' "${wallpapers[@]}" | rofi -dmenu -i -no-custom -p "Wallpaper")

if [ -z "$WALLPAPER" ]; then
    exit 0
fi

case "$WALLPAPER" in
    */*|*..*) die "Invalid wallpaper selection: $WALLPAPER" ;;
esac
[ -f "$WALLPAPER_DIR/$WALLPAPER" ] || die "Wallpaper not found: $WALLPAPER_DIR/$WALLPAPER"

# 2. Set the wallpaper with feh and run Pywal (quietly, without terminal output)
feh --bg-fill "$WALLPAPER_DIR/$WALLPAPER"
"$HOME/.local/bin/wal" -q -i "$WALLPAPER_DIR/$WALLPAPER" -n

# 3. Parse the generated Pywal colors ($color0, $color4, $color15) as data (never sourced)
WAL_COLORS="$HOME/.cache/wal/colors.sh"
[ -f "$WAL_COLORS" ] || die "Pywal color file not found: $WAL_COLORS"
color0=""; color4=""; color15=""
while IFS='=' read -r key val || [ -n "$key" ]; do
    val="${val%%[[:space:]]#*}"; val="${val//[[:space:]\"\']/}"
    case "$key" in
        color0|color4|color15) is_hex_color "$val" && printf -v "$key" '%s' "$val" ;;
    esac
done < "$WAL_COLORS"

if [ -z "$color0" ] || [ -z "$color15" ] || [ -z "$color4" ]; then
    die "Could not parse valid #rrggbb colors (color0, color15, color4) from $WAL_COLORS"
fi

# 4. Apply the colors through the central Color Engine (BG=color0, FG=color15, ACCENT=color4)
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$color0" "$color15" "$color4"
