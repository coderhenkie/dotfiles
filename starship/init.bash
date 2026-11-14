# ==========================================
# Starship prompt for Bash (sourced from ~/.bashrc, hook added by setup.sh)
# ==========================================
# Layout: ~/dotfiles/starship/starship.toml   Colors: ~/.cache/theme/starship-palette.toml
# Both are merged into ~/.cache/theme/starship.toml by scripts/apply-theme.sh.

command -v starship >/dev/null 2>&1 || return 0
# The Linux console (TTY) has no Nerd Font: keep the plain Debian prompt there
[ "${TERM:-}" = "linux" ] && return 0

__ce_starship_layout="$HOME/dotfiles/starship/starship.toml"
__ce_starship_palette="$HOME/.cache/theme/starship-palette.toml"
export STARSHIP_CONFIG="$HOME/.cache/theme/starship.toml"

# Re-merge when the layout was edited after the last theme change (so edits show up in a new shell)
if [ -f "$__ce_starship_palette" ] && [ -f "$__ce_starship_layout" ] \
    && { [ "$__ce_starship_layout" -nt "$STARSHIP_CONFIG" ] || [ "$__ce_starship_palette" -nt "$STARSHIP_CONFIG" ]; }; then
    cat "$__ce_starship_layout" "$__ce_starship_palette" > "$STARSHIP_CONFIG"
fi
unset __ce_starship_layout __ce_starship_palette

# No Color Engine palette yet (apply-theme.sh never ran): keep the default prompt
if [ ! -f "$STARSHIP_CONFIG" ]; then
    unset STARSHIP_CONFIG
    return 0
fi

# Window title = current folder, so the i3 title bar and the Polybar window module
# (xwindow) show where each terminal is
__ce_window_title() { printf '\e]0;%s\a' "${PWD/#$HOME/\~}"; }
starship_precmd_user_func="__ce_window_title"

eval "$(starship init bash)"
