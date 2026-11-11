#!/usr/bin/env bash

I3_CONFIG="$HOME/dotfiles/i3/config"
export DISPLAY="${DISPLAY:-:0}"
if [ -z "${I3SOCK:-}" ]; then
    I3SOCK=$(ls "/run/user/$(id -u)/i3/"ipc-socket.* 2>/dev/null | head -n 1 || true)
    [ -n "$I3SOCK" ] && export I3SOCK
fi

# Check whether we are currently using Mod4 (Super/Win) or Mod1 (Alt)
if grep -Fq 'set $mod Mod4' "$I3_CONFIG"; then
    echo "==> Switching from Super/Win key (Mod4) to Alt key (Mod1)..."
    sed -i 's/set \$mod Mod4/set \$mod Mod1/' "$I3_CONFIG"
    i3-msg reload
    echo "[OK] Mod key is now Alt (Mod1)!"

elif grep -Fq 'set $mod Mod1' "$I3_CONFIG"; then
    echo "==> Switching from Alt key (Mod1) to Super/Win key (Mod4)..."
    sed -i 's/set \$mod Mod1/set \$mod Mod4/' "$I3_CONFIG"
    i3-msg reload
    echo "[OK] Mod key is now Super/Win (Mod4)!"

else
    echo "[!] Could not find the mod variable."
    echo "Make sure 'set \$mod Mod4' or 'set \$mod Mod1' is present in your i3 config."
fi
