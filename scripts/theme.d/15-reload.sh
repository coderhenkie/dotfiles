# shellcheck shell=bash disable=SC2154  # variables come from apply-theme.sh and the earlier parts
# scripts/theme.d/15-reload.sh: part of apply-theme.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 15. Live Reload (unless --no-reload is passed)
# ==========================================
if [ "$RELOAD" = 1 ]; then
    # Kitty supports live config reload via SIGUSR1
    if pgrep -x "kitty" > /dev/null; then
        pkill -USR1 -x kitty || true
    fi

    # btop supports live theme/config reload via SIGUSR2
    if pgrep -x "btop" > /dev/null; then
        pkill -USR2 -x btop || true
    fi

    # Dunst re-reads colours live, but a font change needs a restart
    # (dunst is D-Bus activated and starts again with the next notification)
    if pgrep -x "dunst" > /dev/null; then
        if [ "$(cat "$CACHE_DIR/.dunst-font" 2>/dev/null)" != "$FONT_UI" ]; then
            pkill -x dunst || true
        else
            dunstctl reload >/dev/null 2>&1 || true
        fi
    fi
    echo "$FONT_UI" > "$CACHE_DIR/.dunst-font"

    if pgrep -x "herdr" > /dev/null && [ -x "$HOME/.local/bin/herdr" ]; then
        "$HOME/.local/bin/herdr" server reload-config >/dev/null 2>&1 || true
    fi

    i3_env

    if i3-msg -t get_version >/dev/null 2>&1; then
        i3-msg restart >/dev/null 2>&1 || true
    fi
fi
