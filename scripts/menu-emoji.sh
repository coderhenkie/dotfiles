#!/usr/bin/env bash
# ==========================================
# Rofi Emoji Picker
# ==========================================
# Search emoji by name, press Enter: the emoji is typed into the focused window
# and also copied to the clipboard. Bound to $mod+Shift+period.
# Emoji list comes from the Unicode data in /usr/share/unicode/emoji/emoji-test.txt
# (package unicode-data); colour glyphs from fonts-noto-color-emoji.
#
# Usage: menu-emoji.sh [-h|--help]

# No set -e: rofi returns non-zero when cancelled with Esc.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need rofi xclip   # xdotool is optional: without it the emoji is only copied

SOURCE="/usr/share/unicode/emoji/emoji-test.txt"
CACHE="$HOME/.cache/emoji-list.txt"

if [ ! -f "$SOURCE" ]; then
    notify -a "Emoji" -u critical "Emoji picker" "Missing dependency: unicode-data"
    die "Missing dependency: unicode-data ($SOURCE)"
fi

# Build "<emoji>  <name>  (<group>)" once; rebuild when the Unicode data changes
if [ ! -s "$CACHE" ] || [ "$SOURCE" -nt "$CACHE" ]; then
    mkdir -p "$(dirname "$CACHE")"
    awk '
        /^# group:/ { group = substr($0, 10); next }
        /; fully-qualified/ {
            split($0, parts, "# ")
            # parts[2] = "<emoji> E<version> <name>"
            n = split(parts[2], w, " ")
            name = ""
            for (i = 3; i <= n; i++) name = name (i > 3 ? " " : "") w[i]
            print w[1] "  " name "  (" group ")"
        }' "$SOURCE" > "$CACHE"
fi

choice=$(rofi -dmenu -i -p "Emoji" -theme-str 'window { width: 40%; } listview { lines: 12; }' < "$CACHE") || exit 0
[ -z "$choice" ] && exit 0
emoji="${choice%%  *}"

printf '%s' "$emoji" | xclip -selection clipboard
# Give focus back to the previous window before typing
sleep 0.15
xdotool type --clearmodifiers -- "$emoji" 2>/dev/null || true
