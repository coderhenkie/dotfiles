#!/usr/bin/env bash

# ==========================================
# Screen Locker (LightDM + light-locker)
# ==========================================
# Syncs the active feh wallpaper with the LightDM GTK Greeter
# and locks the current session via light-locker / dm-tool.

set -eu

DOTFILES_DIR="$HOME/dotfiles"
CACHE_DIR="$HOME/.cache/theme"
SYSTEM_THEME_DIR="/usr/share/themes/ColorEngine"
DEFAULT_WALLPAPER="$DOTFILES_DIR/wallpapers/background.jpg"

mkdir -p "$CACHE_DIR"

# 1. Resolve active wallpaper from ~/.fehbg (fallback to default wallpaper)
WALLPAPER_PATH=""
if [ -f "$HOME/.fehbg" ]; then
    WALLPAPER_PATH=$(sed -n "s/.*'\([^']*\)'.*/\1/p" "$HOME/.fehbg" | head -n 1 || true)
fi
if [ -z "$WALLPAPER_PATH" ] || [ ! -f "$WALLPAPER_PATH" ]; then
    WALLPAPER_PATH="$DEFAULT_WALLPAPER"
fi

# 2. Sync active wallpaper to cache and system ColorEngine theme directory
if [ -f "$WALLPAPER_PATH" ]; then
    cp -f "$WALLPAPER_PATH" "$CACHE_DIR/lock-wallpaper"
    chmod 644 "$CACHE_DIR/lock-wallpaper"
    if [ -d "$SYSTEM_THEME_DIR" ] && [ -w "$SYSTEM_THEME_DIR" ]; then
        cp -f "$WALLPAPER_PATH" "$SYSTEM_THEME_DIR/wallpaper"
        chmod 644 "$SYSTEM_THEME_DIR/wallpaper"
        if [ -f "$CACHE_DIR/gtk.css" ]; then
            mkdir -p "$SYSTEM_THEME_DIR/gtk-3.0"
            cp -f "$CACHE_DIR/gtk.css" "$SYSTEM_THEME_DIR/gtk-3.0/gtk.css"
            chmod 644 "$SYSTEM_THEME_DIR/gtk-3.0/gtk.css"
        fi
    elif [ ! -d "$SYSTEM_THEME_DIR" ]; then
        echo "lock: $SYSTEM_THEME_DIR missing; run ~/dotfiles/scripts/lockscreen-setup.sh once" >&2
    fi
fi

# 3. Ensure DISPLAY is set when invoked from keybindings or terminal
export DISPLAY="${DISPLAY:-:0}"

# 4. Ensure light-locker daemon is running in the session
if ! pgrep -x "light-locker" >/dev/null 2>&1; then
    nohup light-locker --lock-after-screensaver=5 --no-late-locking --lock-on-suspend >/dev/null 2>&1 &
    sleep 0.3
fi

# 5. Lock the session via light-locker-command (fallback to dm-tool)
if command -v light-locker-command >/dev/null 2>&1; then
    light-locker-command -l || dm-tool lock
elif command -v dm-tool >/dev/null 2>&1; then
    dm-tool lock
fi
