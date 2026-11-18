#!/usr/bin/env bash
# ==========================================
# Wallpaper & Pywal Theme Picker (Rofi)
# ==========================================
# Selects a wallpaper from <dotfiles>/wallpapers/ in a thumbnail grid (thumbnails cached in
# ~/.cache/theme/wallpaper-thumbs, rebuilt when a wallpaper changes), sets it with feh, generates a palette
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

need rofi feh convert

WALLPAPER_DIR="$DOTFILES_DIR/wallpapers"
mkdir -p "$WALLPAPER_DIR"

mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 1 -xtype f -printf '%f\n' 2>/dev/null | sort)
[ "${#wallpapers[@]}" -gt 0 ] || exit 0

# 1. Thumbnails (16:9, center crop), only for new or changed wallpapers, in parallel
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/theme/wallpaper-thumbs"
mkdir -p "$THUMB_DIR"
make_thumb() {  # <source> <thumbnail>
    convert "$1[0]" -auto-orient -thumbnail '384x216^' -gravity center -extent 384x216 "$2.tmp.png" 2>/dev/null \
        && mv "$2.tmp.png" "$2" || rm -f "$2.tmp.png"
}
todo=()
for wp in "${wallpapers[@]}"; do
    [ "$THUMB_DIR/$wp.png" -nt "$WALLPAPER_DIR/$wp" ] || todo+=("$wp")
done
if [ "${#todo[@]}" -gt 0 ]; then
    [ "${#todo[@]}" -gt 3 ] && notify "Wallpapers" "Generating ${#todo[@]} previews (only once)..."
    jobs_max=$(nproc 2>/dev/null || echo 4)
    for wp in "${todo[@]}"; do
        while [ "$(jobs -rp | wc -l)" -ge "$jobs_max" ]; do wait -n; done
        make_thumb "$WALLPAPER_DIR/$wp" "$THUMB_DIR/$wp.png" &
    done
    wait
fi

# Preselect the active wallpaper (path from ~/.fehbg)
selected=0
for i in "${!wallpapers[@]}"; do
    grep -qF "/${wallpapers[$i]}'" "$HOME/.fehbg" 2>/dev/null && { selected=$i; break; }
done

# 2. Select a wallpaper via Rofi (-no-custom prevents arbitrary paths); the thumbnail is the row icon
ROFI_THEME='
window { width: 70%; }
listview { columns: 4; lines: 2; spacing: 10px; flow: horizontal; }
element { orientation: vertical; padding: 6px; spacing: 4px; }
element-icon { size: 12em; padding: 0; horizontal-align: 0.5; }
element-text { horizontal-align: 0.5; }
'
# Rows show the name without extension; -format i returns the index into wallpapers[].
index=$(for wp in "${wallpapers[@]}"; do
        printf '%s\0icon\x1f%s\n' "${wp%.*}" "$THUMB_DIR/$wp.png"
    done | rofi -dmenu -i -no-custom -show-icons -format i -p "Wallpaper" \
        -selected-row "$selected" -theme-str "$ROFI_THEME")

case "$index" in ''|*[!0-9]*) exit 0 ;; esac
WALLPAPER="${wallpapers[$index]:-}"
[ -n "$WALLPAPER" ] || exit 0

case "$WALLPAPER" in
    */*|*..*) die "Invalid wallpaper selection: $WALLPAPER" ;;
esac
[ -f "$WALLPAPER_DIR/$WALLPAPER" ] || die "Wallpaper not found: $WALLPAPER_DIR/$WALLPAPER"

# 3. Set the wallpaper with feh and run Pywal (quietly, without terminal output)
feh --bg-fill "$WALLPAPER_DIR/$WALLPAPER"
"$HOME/.local/bin/wal" -q -i "$WALLPAPER_DIR/$WALLPAPER" -n

# 4. Parse the generated Pywal colors ($color0, $color4, $color15) as data (never sourced)
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

# 5. Apply the colors through the central Color Engine (BG=color0, FG=color15, ACCENT=color4)
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$color0" "$color15" "$color4"
