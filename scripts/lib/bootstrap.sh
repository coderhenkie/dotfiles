#!/usr/bin/env bash
# ==========================================
# Install/bootstrap helpers shared by setup.sh and apply-theme.sh (source it, don't run it)
# ==========================================
#   ensure_link <source> <link>      idempotent symlink: nothing when already right, replaces a wrong
#                                    or dead link, moves a real file/dir aside to <link>.bak.<epoch>
#   install_script <name> <url> [sh|bash]
#                                    download a vendor install script to a temp file (timeout), check
#                                    that it is a non-empty script (#!), then run it; non-zero on failure
#   thorium_bootstrap_prefs          first-run Thorium Preferences (GTK theme colors); never overwrites
#   btop_conf_init                   create btop/btop.conf from the tracked btop.conf.default if missing
#   theme_runtime_links              ~/.local/bin/lock, herdr config and btop theme -> repo / theme cache
#
# Needs lib/common.sh (sourced below; it is guarded against double sourcing).

# shellcheck source-path=SCRIPTDIR source=common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"

ensure_link() {
    local src="$1" dst="$2" bak
    if [ -L "$dst" ]; then
        [ "$(readlink "$dst")" = "$src" ] && return 0
        [ -e "$src" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ] && return 0
        rm -f "$dst"                       # wrong or dead link: replace it
    elif [ -e "$dst" ]; then
        bak="$dst.bak.$(date +%s)"         # never nest into an older backup
        mv "$dst" "$bak"
        warn "Moved existing $dst to $bak"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sn "$src" "$dst"
}

install_script() {
    local name="$1" url="$2" shell="${3:-bash}" tmp rc=0
    tmp=$(mktemp) || return 1
    if ! curl -fsSL --max-time 120 --retry 2 -o "$tmp" "$url"; then
        rm -f "$tmp"
        warn "$name: could not download its installer ($url)."
        return 1
    fi
    if [ ! -s "$tmp" ] || [ "$(head -c 2 "$tmp")" != '#!' ]; then
        rm -f "$tmp"
        warn "$name: the installer from $url is empty or not a script; not run."
        return 1
    fi
    "$shell" "$tmp" || rc=$?
    rm -f "$tmp"
    [ "$rc" -eq 0 ] || warn "$name: installer exited with status $rc."
    return "$rc"
}

thorium_bootstrap_prefs() {
    local prefs="$HOME/.config/thorium/Default/Preferences"
    mkdir -p "$(dirname "$prefs")"
    [ -f "$prefs" ] && return 0
    cat <<EOF > "$prefs"
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
}

btop_conf_init() {
    local dir="$DOTFILES_DIR/btop"
    [ -f "$dir/btop.conf" ] && return 0
    [ -f "$dir/btop.conf.default" ] || return 0
    cp "$dir/btop.conf.default" "$dir/btop.conf"
}

theme_runtime_links() {
    mkdir -p "$HOME/.local/bin"
    if [ -f "$DOTFILES_DIR/scripts/lock.sh" ]; then
        chmod +x "$DOTFILES_DIR/scripts/lock.sh"
        ln -sfn "$DOTFILES_DIR/scripts/lock.sh" "$HOME/.local/bin/lock"
    fi
    # herdr: only config.toml is linked, so live sockets/logs stay out of git
    ensure_link "$THEME_CACHE/herdr.toml" "$HOME/.config/herdr/config.toml"
    ensure_link "$THEME_CACHE/btop.theme" "$HOME/.config/btop/themes/color_engine.theme"
}
