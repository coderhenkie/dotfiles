#!/usr/bin/env bash

HOTKEYS_FILE="$HOME/dotfiles/i3/hotkeys.conf"
DEFAULT_HOTKEYS="$HOME/dotfiles/i3/hotkeys.default"

if [ ! -f "$HOTKEYS_FILE" ] && [ -f "$DEFAULT_HOTKEYS" ]; then
    cp "$DEFAULT_HOTKEYS" "$HOTKEYS_FILE"
fi

export DISPLAY="${DISPLAY:-:0}"
if [ -z "${I3SOCK:-}" ]; then
    I3SOCK=$(ls "/run/user/$(id -u)/i3/"ipc-socket.* 2>/dev/null | head -n 1 || true)
    [ -n "$I3SOCK" ] && export I3SOCK
fi

# Check whether we are currently using Mod4 (Super/Win) or Mod1 (Alt)
if grep -Fq 'set $mod Mod4' "$HOTKEYS_FILE"; then
    echo "==> Switching from Super/Win key (Mod4) to Alt key (Mod1)..."
    sed -i 's/set \$mod Mod4/set \$mod Mod1/' "$HOTKEYS_FILE"
    i3-msg reload
    echo "[OK] Mod key is now Alt (Mod1)!"

elif grep -Fq 'set $mod Mod1' "$HOTKEYS_FILE"; then
    echo "==> Switching from Alt key (Mod1) to Super/Win key (Mod4)..."
    sed -i 's/set \$mod Mod1/set \$mod Mod4/' "$HOTKEYS_FILE"
    i3-msg reload
    echo "[OK] Mod key is now Super/Win (Mod4)!"

else
    echo "[!] Could not find the mod variable."
    echo "Make sure 'set \$mod Mod4' or 'set \$mod Mod1' is present in $HOTKEYS_FILE."
fi
