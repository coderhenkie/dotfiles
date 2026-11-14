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

# "Command finished" notification (dunst) for commands that ran 60s or longer, like starship's
# own cmd_duration notification but only for commands that do a job (installs, builds, copies):
# not for programs you work in and close yourself (editors, ssh, monitors, REPLs), and not when
# a command was stopped with Ctrl+C. Add programs to skip with: CE_NOTIFY_SKIP+=(name) in ~/.bashrc
CE_NOTIFY_AFTER=${CE_NOTIFY_AFTER:-60}
CE_NOTIFY_SKIP=(nvim vim vi view nano micro emacs less more most man info bat htop btop top atop nvtop
    ssh mosh sftp ftp telnet tmux screen zellij herdr claude obsidian lazygit tig yazi ranger nnn lf mc
    python python3 ipython node bash sh zsh fish psql mysql sqlite3 watch fzf cmatrix weechat irssi
    nmtui bluetoothctl alsamixer pulsemixer ncdu journalctl dmesg "${CE_NOTIFY_SKIP[@]}")
__ce_notify_finished() {
    local status=${STARSHIP_CMD_STATUS:-0} start=${STARSHIP_START_TIME-}
    [ -n "$start" ] && command -v notify-send >/dev/null || return 0
    local now=${EPOCHREALTIME/[.,]/}; now=$((now / 1000))    # ms, like `starship time`
    local secs=$(( (now - start) / 1000 ))
    [ "$secs" -ge "$CE_NOTIFY_AFTER" ] && [ "$status" -ne 130 ] || return 0   # 130 = Ctrl+C
    local cmd word
    cmd=$(fc -ln -1 2>/dev/null); cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    # The program that ran: skip sudo/env/time/VAR=value prefixes and a path (/usr/bin/nvim)
    for word in $cmd; do
        case "$word" in sudo|doas|env|time|nice|nohup|command|exec|*=*|-*) continue ;; esac
        word=${word##*/}; break
    done
    local skip; for skip in "${CE_NOTIFY_SKIP[@]}"; do [ "$word" = "$skip" ] && return 0; done
    local took; ((secs >= 3600)) && took="$((secs / 3600))h$((secs % 3600 / 60))m" || took="$((secs / 60))m$((secs % 60))s"
    if [ "$status" -eq 0 ]; then
        notify-send -a "Terminal" -u low "Command finished ($took)" "$cmd" &
    else
        notify-send -a "Terminal" -u normal "Command failed: exit $status ($took)" "$cmd" &
    fi
    disown 2>/dev/null
}
__ce_precmd() { __ce_notify_finished; __ce_window_title; }
starship_precmd_user_func="__ce_precmd"

eval "$(starship init bash)"
