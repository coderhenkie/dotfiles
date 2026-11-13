#!/usr/bin/env bash
# ==========================================
# Font modules (sourced by setup.sh, apply-theme.sh, menu-font.sh, rofi-icons.sh)
# ==========================================
# Every font is a small module in ~/dotfiles/fonts/<id>.font (see iosevka.font).
# The active font id is stored in ~/.cache/theme/current.font; apply-theme.sh puts
# that font into every generated config. Adding a font = adding one .font file.
#
# Fonts are installed into /usr/local/share/fonts/ColorEngine/<id>: a system font
# directory owned by the desktop user (provisioned once by lockscreen-setup.sh), so
# the LightDM greeter can use them and the picker can install fonts without sudo.
# Falls back to ~/.local/share/fonts/ColorEngine/<id> when that dir is not available.

FONTS_MODULE_DIR="$HOME/dotfiles/fonts"
FONTS_SYSTEM_DIR="/usr/local/share/fonts/ColorEngine"
FONTS_USER_DIR="$HOME/.local/share/fonts/ColorEngine"
FONTS_ACTIVE_FILE="$HOME/.cache/theme/current.font"
FONTS_DEFAULT="iosevka"
FONTS_STYLES=(Regular Bold Italic BoldItalic)

font_root() {
    if [ -d "$FONTS_SYSTEM_DIR" ] && [ -w "$FONTS_SYSTEM_DIR" ]; then
        echo "$FONTS_SYSTEM_DIR"
    else
        echo "$FONTS_USER_DIR"
    fi
}

font_ids() {
    local f
    for f in "$FONTS_MODULE_DIR"/*.font; do
        [ -f "$f" ] && basename "$f" .font
    done
}

# font_load <id>: sets FONT_ID, FONT_NAME, FONT_DESCRIPTION, FONT_ASSET, FONT_FILE_PREFIX,
# FONT_FAMILY and FONT_FAMILY_MONO. Returns 1 for an unknown id.
font_load() {
    local file="$FONTS_MODULE_DIR/$1.font"
    [ -f "$file" ] || return 1
    FONT_NAME="" FONT_DESCRIPTION="" FONT_ASSET="" FONT_FILE_PREFIX="" FONT_FAMILY="" FONT_FAMILY_MONO=""
    # shellcheck disable=SC1090
    source "$file"
    FONT_ID="$1"
}

font_active() {
    local id
    id=$(cat "$FONTS_ACTIVE_FILE" 2>/dev/null)
    [ -n "$id" ] && [ -f "$FONTS_MODULE_DIR/$id.font" ] || id="$FONTS_DEFAULT"
    echo "$id"
}

font_set_active() {
    mkdir -p "$(dirname "$FONTS_ACTIVE_FILE")"
    echo "$1" > "$FONTS_ACTIVE_FILE"
}

# font_is_installed <id>: true when fontconfig knows both the UI and the Mono family
font_is_installed() {
    font_load "$1" || return 1
    [ -n "$(fc-list "$FONT_FAMILY" family 2>/dev/null)" ] && [ -n "$(fc-list "$FONT_FAMILY_MONO" family 2>/dev/null)" ]
}

# font_file <id>: path of the Regular UI font file (used to render the Rofi icons)
font_file() {
    font_load "$1" || return 1
    fc-match -f '%{file}' "$FONT_FAMILY:style=Regular"
}

# font_install <id>: download (checksum-verified) and install Regular/Bold/Italic/BoldItalic
# of the UI and Mono variants. Needs scripts/lib/github-download.sh to be sourced.
font_install() {
    font_load "$1" || { echo "[!] Unknown font module: $1" >&2; return 1; }
    local dest tmp style f
    dest="$(font_root)/$FONT_ID"
    tmp=$(mktemp -d)
    # GitHub API (digest per asset) first; when that fails (e.g. the 60/hour API rate limit),
    # fall back to the plain download URL verified against the release's SHA-256.txt
    if ! gh_install_latest "ryanoasis/nerd-fonts" "^${FONT_ASSET//./\\.}\$" "$tmp/$FONT_ASSET" \
        && ! gh_install_latest_sumfile "ryanoasis/nerd-fonts" "$FONT_ASSET" "SHA-256.txt" "$tmp/$FONT_ASSET"; then
        rm -rf "$tmp"
        return 1
    fi
    mkdir -p "$dest"
    for style in "${FONTS_STYLES[@]}"; do
        # Not every font ships every style (Fira Code has no italics): skip missing ones
        for f in "$FONT_FILE_PREFIX-$style.ttf" "${FONT_FILE_PREFIX}Mono-$style.ttf"; do
            tar -xJf "$tmp/$FONT_ASSET" -C "$dest" "$f" 2>/dev/null || true
        done
    done
    tar -xJf "$tmp/$FONT_ASSET" -C "$dest" LICENSE.md 2>/dev/null \
        || tar -xJf "$tmp/$FONT_ASSET" -C "$dest" LICENSE 2>/dev/null || true
    rm -rf "$tmp"
    chmod -R a+rX "$dest"
    if [ ! -f "$dest/$FONT_FILE_PREFIX-Regular.ttf" ]; then
        echo "[!] $FONT_NAME: $FONT_FILE_PREFIX-Regular.ttf not found in $FONT_ASSET." >&2
        return 1
    fi
    fc-cache -f "$dest" >/dev/null 2>&1
    echo "[OK] $FONT_NAME Nerd Font installed in $dest."
}
