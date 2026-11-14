#!/usr/bin/env bash
# Obsidian app launcher (Rofi entry, `obsidian-app`, obsidian:// links).
# The app has its own Sync, so headless sync (obsidian-sync.sh) is paused first; its daemon starts it
# again once the app is closed. Already running? Hand over links/files and focus it.

APPIMAGE="$HOME/appimages/obsidian.appimage"

if pgrep -x obsidian >/dev/null; then
    [ $# -gt 0 ] && setsid "$APPIMAGE" "$@" >/dev/null 2>&1 < /dev/null &
    i3-msg -q '[class="(?i)obsidian"] focus'
else
    "$HOME/dotfiles/scripts/obsidian-sync.sh" pause
    exec "$APPIMAGE" "$@"
fi
