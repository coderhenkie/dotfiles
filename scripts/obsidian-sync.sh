#!/usr/bin/env bash
# ==========================================
# Obsidian Sync without the app (Obsidian Headless + handoff to the desktop app)
# ==========================================
# Notes are mostly edited in Neovim (`obsidian`), so Sync runs through Obsidian Headless
# (`ob sync --continuous`, npm package obsidian-headless, needs Node >= 22: install-node.sh).
# The desktop app has its own Sync, and Obsidian says the two must never run at the same time on one
# device, so they take turns: the daemon stops headless sync while the app is running and starts it
# again once the app is closed; obsidian-app.sh pauses it *before* the app starts.
#
#   obsidian-sync.sh setup [vault-path]  one-time, in a terminal: backup, `ob login`, link the vault
#   obsidian-sync.sh daemon              started by i3 at login (does nothing until setup is done)
#   obsidian-sync.sh pause               stop headless sync now and keep it off while the app starts
#   obsidian-sync.sh status              what's running + `ob sync-status`
#   obsidian-sync.sh log                 follow the sync log
#
# Remote vault, login token and sync state are kept by `ob` itself; the linked local vault path is
# stored in ~/.config/obsidian-sync/vault.

# No set -e: daemon loop and status checks expect non-zero exits from pgrep, kill and ob.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/obsidian.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/obsidian.sh"

OB="$HOME/.local/bin/ob"
export PATH="$HOME/.local/bin:$PATH"   # ob runs via `env node` (install-node.sh); i3 may start us without it
CONF_DIR="$HOME/.config/obsidian-sync"
VAULT_FILE="$CONF_DIR/vault"
RUN="$(runtime_dir)/obsidian-sync"
PIDFILE="$RUN.pid"
HOLD="$RUN.hold"
LOG="$HOME/.cache/obsidian-sync.log"

ensure_log() {
    mkdir -p "$(dirname "$LOG")"
    (umask 077 && : >> "$LOG")
    chmod 600 "$LOG" 2>/dev/null || true
}

rotate_log() {
    ensure_log
    if [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt 1000000 ]; then
        # Copy + truncate in place so an open append fd keeps writing to the same inode
        if (umask 077 && tail -n 2000 "$LOG" > "$LOG.tmp"); then
            cat "$LOG.tmp" > "$LOG"
            rm -f "$LOG.tmp"
        fi
    fi
}

app_running() { pgrep -x obsidian >/dev/null 2>&1; }
child_pid() { local p; p=$(cat "$PIDFILE" 2>/dev/null) && kill -0 "$p" 2>/dev/null && echo "$p"; }

stop_child() { # graceful: ob finishes the current transfer on SIGTERM; hard stop after 10 s
    local pid                  # (its shutdown sometimes hangs on "Waiting to connect to server")
    pid=$(child_pid) || return 0
    kill -TERM "$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
    if kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
    ensure_log
    echo "$(date '+%F %T') headless sync stopped" >> "$LOG"
}

case "${1:-}" in
-h|--help)
    help_from_header
    exit 0
    ;;

setup)
    [ -x "$OB" ] || die "Obsidian Headless is missing: run $DOTFILES_DIR/setup.sh (or install-node.sh + npm install -g --prefix ~/.local obsidian-headless)."
    vault="${2:-}"
    if [ -z "$vault" ]; then
        vault=$(obsidian_default_vault || true)
    fi
    if [ -z "$vault" ]; then
        read -r -p "Local vault folder (created if missing): " vault
        vault="${vault/#\~/$HOME}"
    fi
    [ -n "$vault" ] || die "No vault path given."
    mkdir -p "$vault"
    vault=$(cd "$vault" && pwd)

    if app_running; then
        die "Close the Obsidian app first (its own Sync must not run during setup)."
    fi
    if [ -n "$(ls -A "$vault" 2>/dev/null)" ]; then
        backup_dir="$HOME/Backups"
        [ -d "$backup_dir" ] || mkdir -m 700 "$backup_dir"
        vname="$(basename "$vault")"
        backup="$backup_dir/obsidian-backup-$vname-$(date +%F_%H%M%S).tar.gz"
        info "Backup of $vault -> $backup"
        (umask 077 && tar -czf "$backup" -C "$(dirname "$vault")" "$vname") || die "Backup failed, stopping."
        chmod 600 "$backup"   # unencrypted copy of private notes: owner-only (old backups are never removed)
    fi

    "$OB" login || exit 1
    echo; echo "Remote vaults:"; "$OB" sync-list-remote || exit 1; echo
    read -r -p "Remote vault name to link to $vault [$(basename "$vault")]: " remote
    remote="${remote:-$(basename "$vault")}"
    "$OB" sync-setup --vault "$remote" --path "$vault" --device-name "$(hostname) (headless)" || exit 1
    # Conflicts (e.g. the app was closed before it uploaded its last edit) become a separate conflict
    # file instead of an automatic merge, which can garble text ("vibeco" + "vibecoden" -> "vibecovibecoden")
    "$OB" sync-config --path "$vault" --conflict-strategy conflict >/dev/null || exit 1

    mkdir -p "$CONF_DIR" && printf '%s\n' "$vault" > "$VAULT_FILE"
    echo
    ok "Linked. Headless sync starts automatically (within a few seconds if the daemon runs,"
    echo "     otherwise at the next login). Check with: obsidian-sync.sh status"
    ;;

daemon)
    i3_env
    single_instance obsidian-sync
    ensure_log
    trap 'stop_child; exit 0' EXIT TERM INT
    fails=0
    while session_alive; do
        vault=$(cat "$VAULT_FILE" 2>/dev/null || true)
        if app_running; then
            stop_child; rm -f "$HOLD"
        elif [ -f "$HOLD" ] && [ $(( $(date +%s) - $(stat -c %Y "$HOLD" 2>/dev/null || echo 0) )) -lt 30 ]; then
            : # obsidian-app.sh is starting the app
        elif [ -n "$vault" ] && [ -d "$vault" ] && [ -x "$OB" ] && ! child_pid >/dev/null; then
            rm -f "$HOLD"
            rotate_log
            echo "$(date '+%F %T') headless sync starting ($vault)" >> "$LOG"
            "$OB" sync --continuous --path "$vault" >> "$LOG" 2>&1 9>&- &
            echo $! > "$PIDFILE"
            # Exits within 30 s = broken (logged out, network, setup): back off, warn once.
            # Keep watching for the app meanwhile.
            for _ in $(seq 1 15); do
                app_running && break
                child_pid >/dev/null || break
                sleep 2
            done
            if app_running || [ -f "$HOLD" ]; then
                continue  # handed over to the app (or paused for it): not a failure
            elif ! child_pid >/dev/null; then
                fails=$((fails + 1))
                [ "$fails" -eq 3 ] && notify -a "Obsidian Sync" -u critical "Headless sync keeps stopping" \
                    "See ~/.cache/obsidian-sync.log (logged out? run: obsidian-sync.sh setup)"
                sleep $(( fails > 5 ? 300 : 30 ))
            else
                fails=0
            fi
            continue
        fi
        sleep 2
    done
    ;;

pause)
    touch "$HOLD"
    stop_child
    ;;

status)
    echo "Linked vault : $(cat "$VAULT_FILE" 2>/dev/null || echo 'none (run: obsidian-sync.sh setup)')"
    echo "Desktop app  : $(app_running && echo running || echo closed)"
    echo "Headless sync: $(child_pid >/dev/null && echo "running (pid $(child_pid))" || echo stopped)"
    [ -f "$VAULT_FILE" ] && { echo; "$OB" sync-status --path "$(cat "$VAULT_FILE")"; }
    ;;

log)
    ensure_log
    exec tail -n 50 -f "$LOG"
    ;;

*)
    help_from_header
    exit 1
    ;;
esac
