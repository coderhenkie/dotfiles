#!/usr/bin/env bash
# Thorium launcher (Rofi entry, default browser). Before Thorium starts, applies Color Engine colors
# that are waiting for Dark Reader (its storage is locked while Thorium runs: darkreader-theme.js).
command -v node >/dev/null && node "$HOME/dotfiles/scripts/darkreader-theme.js" pending >/dev/null 2>&1
exec "$HOME/.local/bin/thorium" "$@"
