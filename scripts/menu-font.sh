#!/usr/bin/env bash
# ==========================================
# Font Picker (Rofi)
# ==========================================
# $mod+Shift+f: choose the desktop font from the modules in <dotfiles>/fonts/.
# Installed fonts are previewed in their own typeface. Picking a font that is not
# installed yet downloads it first (checksum-verified, a few MB). The choice is
# applied everywhere through the Color Engine (apply-theme.sh): Polybar, i3, Rofi,
# dunst, Kitty, GTK/Thunar, LightDM, Zathura, Spotify and web pages in Thorium.
#
# Usage: menu-font.sh [-h|--help]

# No set -e: rofi returns non-zero on Esc/cancel and font_install errors are handled with notifications.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/github-download.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/github-download.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fonts.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/fonts.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need rofi

ICON_ACTIVE=$'\U000F012C'    # nf-md-check
ICON_INSTALLED=$'\U000F06D6' # nf-md-format_font
ICON_DOWNLOAD=$'\U000F01DA'  # nf-md-download

active=$(font_active)
ids=()
rows=()
for id in $(font_ids); do
    font_load "$id" || continue
    ids+=("$id")
    name=$(pango_escape "$FONT_NAME")
    desc=$(pango_escape "$FONT_DESCRIPTION")
    if [ "$id" = "$active" ]; then
        rows+=("$ICON_ACTIVE  <span font_family=\"$FONT_FAMILY\">$name</span>  <span alpha=\"60%\">$desc  (active)</span>")
    elif font_is_installed "$id"; then
        rows+=("$ICON_INSTALLED  <span font_family=\"$FONT_FAMILY\">$name</span>  <span alpha=\"60%\">$desc</span>")
    else
        rows+=("$ICON_DOWNLOAD  $name  <span alpha=\"60%\">$desc  (download)</span>")
    fi
done

index=$(printf '%s\n' "${rows[@]}" | rofi -dmenu -i -markup-rows -format i -no-custom -p "Font" \
    -mesg "Installed fonts are previewed in their own typeface" \
    -theme-str 'window { width: 66%; } listview { lines: 7; }')
if [ -z "$index" ] || [ "$index" -lt 0 ]; then
    exit 0
fi
id="${ids[$index]}"
[ "$id" = "$active" ] && exit 0
font_load "$id"

if ! font_is_installed "$id"; then
    notify -a "Font" -u low "Downloading $FONT_NAME" "Checksum-verified Nerd Font, a few MB..."
    if ! err=$(font_install "$id" 2>&1 >/dev/null); then
        notify -a "Font" -u critical "Font install failed" \
            "$FONT_NAME could not be downloaded or verified.\n$(grep -m1 '^\[!\]' <<< "$err" || true)"
        exit 1
    fi
    font_load "$id"
fi

font_set_active "$id"

# Re-apply the current colours: regenerates every config with the new font and reloads the desktop
# shellcheck disable=SC2119  # theme_load without argument loads active theme
theme_load || exit 1
# shellcheck disable=SC2154  # bg, fg, accent are set by theme_load
bash "$DOTFILES_DIR/scripts/apply-theme.sh" "$bg" "$fg" "$accent" >/dev/null 2>&1

msg="Applied everywhere."
pgrep -x thorium >/dev/null 2>&1 && msg="$msg Restart Thorium for web pages."
notify -a "Font" "Font: $FONT_NAME" "$msg"
