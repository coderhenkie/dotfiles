# shellcheck shell=bash disable=SC2154  # variables come from apply-theme.sh and the earlier parts
# scripts/theme.d/14-darkreader.sh: part of apply-theme.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 14. Dark Reader in Thorium (scripts/darkreader-theme.js)
# ==========================================
# Website dark mode in the theme's colors. Its storage is locked while Thorium runs; then the colors
# are applied at Thorium's next start (scripts/thorium-launch.sh).
if command -v node >/dev/null 2>&1; then
    node "$DOTFILES_DIR/scripts/darkreader-theme.js" apply >/dev/null 2>&1 || true
fi

