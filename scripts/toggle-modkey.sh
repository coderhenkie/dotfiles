#!/usr/bin/env bash
# ==========================================
# Toggle i3 Mod Key (Super <-> Alt)
# ==========================================
# Switches `set $mod` in <dotfiles>/i3/hotkeys.conf between Mod4 (Super/Win)
# and Mod1 (Alt) and reloads i3 live.
#
# Usage: toggle-modkey.sh [-h|--help]

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

need i3-msg
i3_env

HOTKEYS_FILE="$DOTFILES_DIR/i3/hotkeys.conf"
DEFAULT_HOTKEYS="$DOTFILES_DIR/i3/hotkeys.default"

if [ ! -f "$HOTKEYS_FILE" ] && [ -f "$DEFAULT_HOTKEYS" ]; then
    cp "$DEFAULT_HOTKEYS" "$HOTKEYS_FILE"
fi

# Check whether we are currently using Mod4 (Super/Win) or Mod1 (Alt)
# shellcheck disable=SC2016  # literal $mod in i3 config
if grep -Fq 'set $mod Mod4' "$HOTKEYS_FILE"; then
    log "Switching from Super/Win key (Mod4) to Alt key (Mod1)..."
    sed -i 's/set \$mod Mod4/set \$mod Mod1/' "$HOTKEYS_FILE"
    i3-msg reload >/dev/null || warn "i3 not reachable: reload i3 to apply the change."
    ok "Mod key is now Alt (Mod1)!"

elif grep -Fq 'set $mod Mod1' "$HOTKEYS_FILE"; then
    log "Switching from Alt key (Mod1) to Super/Win key (Mod4)..."
    sed -i 's/set \$mod Mod1/set \$mod Mod4/' "$HOTKEYS_FILE"
    i3-msg reload >/dev/null || warn "i3 not reachable: reload i3 to apply the change."
    ok "Mod key is now Super/Win (Mod4)!"

else
    warn "Could not find the mod variable."
    die "Make sure 'set \$mod Mod4' or 'set \$mod Mod1' is present in $HOTKEYS_FILE."
fi
