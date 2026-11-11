#!/usr/bin/env bash

I3_CONFIG="$HOME/dotfiles/i3/config"
export DISPLAY="${DISPLAY:-:0}"
if [ -z "${I3SOCK:-}" ]; then
    I3SOCK=$(ls "/run/user/$(id -u)/i3/"ipc-socket.* 2>/dev/null | head -n 1 || true)
    [ -n "$I3SOCK" ] && export I3SOCK
fi

# Controleer of we in de Mod4 (Win) of Mod1 (Alt) state zitten
if grep -Fq 'set $mod Mod4' "$I3_CONFIG"; then
    echo "==> Switchen van Windows-toets (Mod4) naar Alt-toets (Mod1)..."
    sed -i 's/set \$mod Mod4/set \$mod Mod1/' "$I3_CONFIG"
    i3-msg reload
    echo "[OK] Modkey is nu Alt!"
    
elif grep -Fq 'set $mod Mod1' "$I3_CONFIG"; then
    echo "==> Switchen van Alt-toets (Mod1) naar Windows-toets (Mod4)..."
    sed -i 's/set \$mod Mod1/set \$mod Mod4/' "$I3_CONFIG"
    i3-msg reload
    echo "[OK] Modkey is nu de Windows-toets!"
    
else
    echo "[!] Kon de mod-variabele niet vinden."
    echo "Zorg dat je 'set \$mod Mod4' of 'set \$mod Mod1' letterlijk in je i3 config hebt staan."
fi
