#!/usr/bin/env bash
# ==========================================
# Theme Selector Menu (Rofi)
# ==========================================
# Lists themes in <dotfiles>/themes/, loads the selected theme's bg/fg/accent
# safely as data via theme_load, and applies it through apply-theme.sh.
#
# Usage: menu-theme.sh [-h|--help]

# No set -e: rofi exits non-zero when the user presses Esc to cancel.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need rofi

THEME_DIR="$DOTFILES_DIR/themes"

themes=()
for f in "$THEME_DIR"/*.theme; do
    [ -f "$f" ] && themes+=("$(basename "$f")")
done
[ "${#themes[@]}" -gt 0 ] || die "No theme files found in $THEME_DIR."

# 1. Open Rofi so you can select a theme with the arrow keys (-no-custom prevents arbitrary paths)
THEME_NAME=$(printf '%s\n' "${themes[@]}" | rofi -dmenu -i -no-custom -p "Theme")

# Exit if Esc is pressed
if [ -z "$THEME_NAME" ]; then
    exit 0
fi

case "$THEME_NAME" in
    */*|*..*) die "Invalid theme selection: $THEME_NAME" ;;
esac

# 2. Load the 3 color variables ($bg, $fg, $accent) as data (never sourced)
theme_load "$THEME_DIR/$THEME_NAME" || exit 1

# 3. Apply the colors through the central Color Engine
# shellcheck disable=SC2154  # bg, fg, accent are set by theme_load
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$bg" "$fg" "$accent"
