#!/usr/bin/env bash
# ==========================================
# Font Picker (Rofi)
# ==========================================
# $mod+Shift+f: choose the desktop font from the modules in ~/dotfiles/fonts/.
# Installed fonts are previewed in their own typeface. Picking a font that is not
# installed yet downloads it first (checksum-verified, a few MB). The choice is
# applied everywhere through the Color Engine (apply-theme.sh): Polybar, i3, Rofi,
# dunst, Kitty, GTK/Thunar, LightDM, Zathura, Spotify and web pages in Thorium.

DOTFILES="$HOME/dotfiles"
# shellcheck source=lib/github-download.sh
source "$DOTFILES/scripts/lib/github-download.sh"
# shellcheck source=lib/fonts.sh
source "$DOTFILES/scripts/lib/fonts.sh"

ICON_ACTIVE=$'\U000F012C'    # nf-md-check
ICON_INSTALLED=$'\U000F06D6' # nf-md-format_font
ICON_DOWNLOAD=$'\U000F01DA'  # nf-md-download

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<< "$1"; }

active=$(font_active)
ids=()
rows=()
for id in $(font_ids); do
    font_load "$id" || continue
    ids+=("$id")
    name=$(esc "$FONT_NAME") desc=$(esc "$FONT_DESCRIPTION")
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
[ -z "$index" ] || [ "$index" -lt 0 ] && exit 0
id="${ids[$index]}"
[ "$id" = "$active" ] && exit 0
font_load "$id"

if ! font_is_installed "$id"; then
    notify-send -a "Font" -u low "Downloading $FONT_NAME" "Checksum-verified Nerd Font, a few MB..." 2>/dev/null
    if ! err=$(font_install "$id" 2>&1 >/dev/null); then
        notify-send -a "Font" -u critical "Font install failed" \
            "$FONT_NAME could not be downloaded or verified.\n$(grep -m1 '^\[!\]' <<< "$err")" 2>/dev/null
        exit 1
    fi
    font_load "$id"
fi

font_set_active "$id"

# Re-apply the current colours: regenerates every config with the new font and reloads the desktop
if [ -f "$HOME/.cache/theme/current.theme" ]; then
    # shellcheck disable=SC1091
    source "$HOME/.cache/theme/current.theme"
else
    # shellcheck disable=SC1091
    source "$DOTFILES/themes/dracula.theme"
fi
bash "$DOTFILES/scripts/apply-theme.sh" "$bg" "$fg" "$accent" >/dev/null 2>&1

msg="Applied everywhere."
pgrep -x thorium >/dev/null && msg="$msg Restart Thorium for web pages."
notify-send -a "Font" "Font: $FONT_NAME" "$msg" 2>/dev/null
