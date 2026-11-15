#!/usr/bin/env bash
# ==========================================
# Shared helpers for setup.sh and scripts/*.sh (source it, don't run it)
# ==========================================
#   source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"     # from scripts/
#
# Sets   DOTFILES_DIR  repo root, derived from this file's location (override: export DOTFILES_DIR)
#        THEME_CACHE   ~/.cache/theme
# Logging (same markers everywhere; warnings/errors go to stderr):
#        log "step"   -> ==> step          info "detail" ->  -> detail
#        ok  "done"   -> [OK] done         warn "problem" -> [!] problem   (stderr)
#        die "fatal"  -> [!] fatal + exit 1
# Helpers:
#        try "what" cmd args...   run an optional step; on failure warn and continue (returns 0)
#        need cmd...              exit with a message (and notification) when a command is missing
#        have cmd                 exit 0 when cmd exists
#        notify [notify-send args...]   desktop notification; silent no-op without notify-send
#        runtime_dir              private per-user runtime dir ($XDG_RUNTIME_DIR or a 0700 fallback)
#        single_instance name     take a non-blocking lock; exits 0 when another instance holds it
#        i3_env                   export DISPLAY and I3SOCK for scripts started outside the i3 session
#        session_alive            for daemon loops: false once the graphical (i3/X) session is gone;
#                                 always true when started without a display (headless use)
#        theme_load [file]        read bg/fg/accent from a .theme file as data (never executed);
#                                 defaults to the active theme, falling back to Dracula
#        is_hex_color value       exit 0 for #rrggbb
#        pango_escape text        escape & < > for rofi -markup-rows / -mesg and notifications
#        help_from_header         print the script's leading comment block (for -h/--help)

# Guard against double sourcing
[ -n "${_DOTFILES_COMMON_LOADED:-}" ] && return 0
_DOTFILES_COMMON_LOADED=1

if [ -z "${DOTFILES_DIR:-}" ]; then
    DOTFILES_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
fi
THEME_CACHE="${THEME_CACHE:-$HOME/.cache/theme}"

log()  { printf '==> %s\n' "$*"; }
info() { printf ' -> %s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

try() {
    local what="$1"; shift
    "$@" || { warn "$what failed (continuing)."; }
    return 0
}

have() { command -v "$1" >/dev/null 2>&1; }

notify() {
    have notify-send || return 0
    notify-send "$@" 2>/dev/null || true
}

need() {
    local c
    for c in "$@"; do
        if ! have "$c"; then
            notify -u critical "Missing dependency" "$c is not installed (${0##*/})"
            die "${0##*/}: $c is not installed."
        fi
    done
}

runtime_dir() {
    local d="${XDG_RUNTIME_DIR:-}"
    if [ -z "$d" ] || [ ! -d "$d" ] || [ ! -O "$d" ]; then
        # Fallback outside a login session: private dir under the user's cache (not a guessable /tmp path)
        d="${XDG_CACHE_HOME:-$HOME/.cache}/run"
        mkdir -p "$d" && chmod 700 "$d"
    fi
    printf '%s\n' "$d"
}

single_instance() {
    local lock
    lock="$(runtime_dir)/$1.lock"
    exec 9>"$lock"
    flock -n 9 || exit 0
}

i3_env() {
    export DISPLAY="${DISPLAY:-:0}"
    if [ -z "${I3SOCK:-}" ]; then
        local s
        for s in "/run/user/$(id -u)/i3/"ipc-socket.*; do
            if [ -S "$s" ]; then export I3SOCK="$s"; break; fi
        done
    fi
    return 0   # no i3 running is fine (console/SSH): callers check i3-msg themselves
}

session_alive() {
    [ -z "${DISPLAY:-}" ] && return 0
    pgrep -u "$UID" -x i3 >/dev/null 2>&1 || xset q >/dev/null 2>&1
}

is_hex_color() { [[ "${1:-}" =~ ^#[0-9a-fA-F]{6}$ ]]; }

theme_load() {
    local file="${1:-}" key val
    if [ -z "$file" ]; then
        file="$THEME_CACHE/current.theme"
        [ -f "$file" ] || file="$DOTFILES_DIR/themes/dracula.theme"
    fi
    [ -f "$file" ] || { warn "theme file not found: $file"; return 1; }
    bg=""; fg=""; accent=""
    while IFS='=' read -r key val || [ -n "$key" ]; do
        val="${val%%[[:space:]]#*}"; val="${val//[[:space:]\"\']/}"
        case "$key" in
            bg|fg|accent) is_hex_color "$val" && printf -v "$key" '%s' "$val" ;;
        esac
    done < "$file"
    if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
        warn "invalid theme file (need bg, fg and accent as #rrggbb): $file"
        return 1
    fi
}

pango_escape() {
    local s="$*"
    s="${s//&/\&amp;}"; s="${s//</\&lt;}"; s="${s//>/\&gt;}"
    printf '%s\n' "$s"
}

help_from_header() {
    # Leading "# " comment lines after the shebang, without the ===== rulers
    sed -n '2,/^[^#]/{/^#/!d; /^# *=\{3,\}/d; s/^# \{0,1\}//p}' "$0"
}
