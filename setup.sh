#!/usr/bin/env bash
# ==========================================
# Debian 13 (Trixie) - i3 & Dotfiles Setup
# ==========================================
# Installs packages, apps and fonts, links the configs into ~/.config and applies the Color Engine.
# Safe to run again: it updates the dotfiles to origin/main first (asking what to do with local
# changes) and then re-runs the newest version of itself.
#
# Usage: setup.sh [-h|--help]        (also works as: curl -fsSL <raw setup.sh URL> | bash)
#
# Environment:
#   DOTFILES_DIR=<path>          clone location (default ~/dotfiles)
#   DOTFILES_SKIP_PREFLIGHT=1    run on something other than Debian 13 / x86_64 anyway
#   DOTFILES_NO_UPGRADE=1        skip the full `nala upgrade` (packages are still installed)
#   DOTFILES_VERIFY=1            require a valid signature on origin/main (git verify-commit) before
#                                updating; also on automatically when git's gpg.ssh.allowedSignersFile is set

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_REPO="https://github.com/coderhenkie/dotfiles.git"
export DOTFILES_DIR

case "${1:-}" in
    -h|--help)
        if [ -f "${BASH_SOURCE[0]:-}" ]; then
            sed -n '2,/^[^#]/{/^#/!d; /^# *=\{3,\}/d; s/^# \{0,1\}//p}' "${BASH_SOURCE[0]}"
        else
            echo "Usage: setup.sh [-h|--help]  (see the header of setup.sh for the environment variables)"
        fi
        exit 0 ;;
esac

# Stop before changing anything when this is not the system the setup was written for
preflight() {
    [ "${DOTFILES_SKIP_PREFLIGHT:-0}" = 1 ] && return 0
    local id="" ver="" arch
    if [ -r /etc/os-release ]; then
        id=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
        ver=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')
    fi
    arch=$(uname -m)
    if [ "$id" != debian ] || [ "$ver" != 13 ] || [ "$arch" != x86_64 ]; then
        echo "[!] This setup is written for Debian 13 (trixie) on x86_64; found ${id:-unknown} ${ver:-?} on $arch." >&2
        echo "    Nothing was changed. Set DOTFILES_SKIP_PREFLIGHT=1 to run it anyway." >&2
        exit 1
    fi
}

if [ "${DOTFILES_SETUP_RELOADED:-0}" != "1" ]; then
    preflight
    echo "==> Starting system configuration..."

    # ==========================================
    # 1. Package Management & Base Tools (Nala, Git, Curl)
    # ==========================================
    echo "==> Updating base packages and installing Nala/Git..."
    sudo apt update
    sudo apt install -y nala curl git

    # No 'nala fetch': it adds extra mirrors on every run, and mixing mirrors that are not in sync
    # breaks installs ("held broken packages"). The Debian installer's mirror is used as-is.
    sudo rm -f /etc/apt/sources.list.d/fetch.sources

    if [ "${DOTFILES_NO_UPGRADE:-0}" = 1 ]; then
        echo "[OK] DOTFILES_NO_UPGRADE=1: skipping the full system upgrade."
    else
        echo "==> Upgrading system via Nala..."
        sudo nala upgrade -y
    fi

    # ==========================================
    # 2. Fetch Latest Dotfiles & Re-exec Latest Setup Script
    # ==========================================
    echo "==> Fetching latest dotfiles..."

    # choose <prompt> <option>...: interactive picker on the terminal (j/k or arrow keys, Enter).
    # Sets CHOICE to the index of the picked option. Reads /dev/tty, so it also works when this
    # script itself is piped in (curl ... | bash).
    choose() {
        local prompt="$1" sel=0 key i n
        shift
        local -a opts=("$@")
        n=${#opts[@]}
        printf '%s  (j/k or arrows, Enter)\n' "$prompt" >/dev/tty
        printf '\e[?25l' >/dev/tty
        while true; do
            for i in "${!opts[@]}"; do
                if [ "$i" -eq "$sel" ]; then
                    printf '\e[2K  \e[1;36m> %s\e[0m\n' "${opts[$i]}"
                else
                    printf '\e[2K    %s\n' "${opts[$i]}"
                fi
            done >/dev/tty
            IFS= read -rsn1 key </dev/tty || key=""
            if [ "$key" = $'\e' ]; then
                IFS= read -rsn2 -t 0.05 key </dev/tty || true
                [ -z "$key" ] && key="esc"
            fi
            case "$key" in
                j|'[B') sel=$(( (sel + 1) % n )) ;;
                k|'[A') sel=$(( (sel - 1 + n) % n )) ;;
                '') break ;;   # Enter
            esac
            printf '\e[%dA' "$n" >/dev/tty
        done
        printf '\e[?25h' >/dev/tty
        CHOICE=$sel
    }

    # Every stash/backup branch made below is also recorded here, so it can be found later
    BACKUP_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/setup-backups.log"
    backup_log() {
        mkdir -p "$(dirname "$BACKUP_LOG")"
        printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$BACKUP_LOG"
    }

    # Opt-in commit signature check (DOTFILES_VERIFY=1, or git's gpg.ssh.allowedSignersFile is set)
    verify_or_stop() { # <revision>
        if [ "${DOTFILES_VERIFY:-0}" != 1 ] \
            && [ -z "$(git -C "$DOTFILES_DIR" config --get gpg.ssh.allowedSignersFile 2>/dev/null || true)" ]; then
            return 0
        fi
        if git -C "$DOTFILES_DIR" verify-commit "$1" >/dev/null 2>&1; then
            echo "[OK] Signature on $1 verified."
        else
            echo "[!] The signature on $1 could not be verified: setup stopped, nothing was updated or run." >&2
            echo "    Check with: git -C $DOTFILES_DIR verify-commit $1" >&2
            exit 1
        fi
    }

    if [ -e "$DOTFILES_DIR/.git" ]; then
        echo "==> Dotfiles directory already exists. Syncing with latest origin/main..."
        DOTFILES_UPDATE=1
        if ! git -C "$DOTFILES_DIR" fetch origin; then
            echo "[!] Could not fetch origin (offline?): continuing with the local version." >&2
            DOTFILES_UPDATE=0
        fi
        LOCAL_CHANGES="" LOCAL_COMMITS=""
        if [ "$DOTFILES_UPDATE" = 1 ]; then
            verify_or_stop origin/main
            LOCAL_CHANGES=$(git -C "$DOTFILES_DIR" status --short)
            LOCAL_COMMITS=$(git -C "$DOTFILES_DIR" log --oneline origin/main..HEAD)
        fi

        # The update below is a hard reset to origin/main: never let it silently destroy local work
        if [ -n "$LOCAL_CHANGES" ] || [ -n "$LOCAL_COMMITS" ]; then
            echo
            echo "[!] $DOTFILES_DIR has local work that the update to origin/main would overwrite:"
            # shellcheck disable=SC2001  # indent every line of a multi-line string
            [ -n "$LOCAL_CHANGES" ] && { echo "    Uncommitted changes:"; sed 's/^/      /' <<< "$LOCAL_CHANGES"; }
            # shellcheck disable=SC2001  # indent every line of a multi-line string
            [ -n "$LOCAL_COMMITS" ] && { echo "    Commits not pushed to origin/main:"; sed 's/^/      /' <<< "$LOCAL_COMMITS"; }
            echo
            BACKUP_REF="setup-backup-$(date +%Y%m%d-%H%M%S)"
            if ( : </dev/tty ) 2>/dev/null; then
                choose "What should happen with these changes?" \
                    "Save them (stash + backup branch), then update to origin/main" \
                    "Discard them and update to origin/main" \
                    "Keep them: skip the update and run setup with the local version" \
                    "Abort setup"
            else
                echo "[!] No terminal to ask on: saving the changes before updating."
                CHOICE=0
            fi
            case "$CHOICE" in
                0)
                    if [ -n "$LOCAL_COMMITS" ]; then
                        git -C "$DOTFILES_DIR" branch "$BACKUP_REF"
                        backup_log "branch $BACKUP_REF (local commits) in $DOTFILES_DIR"
                        echo "[OK] Local commits saved in branch '$BACKUP_REF'."
                        echo "     Bring them back with: git -C $DOTFILES_DIR merge $BACKUP_REF"
                    fi
                    if [ -n "$LOCAL_CHANGES" ]; then
                        git -C "$DOTFILES_DIR" stash push -u -m "$BACKUP_REF" >/dev/null
                        backup_log "stash $(git -C "$DOTFILES_DIR" rev-parse --short "stash@{0}") '$BACKUP_REF' (uncommitted changes) in $DOTFILES_DIR"
                        echo "[OK] Uncommitted changes stashed as '$BACKUP_REF' (recorded in $BACKUP_LOG)."
                        echo "     Restore them with: git -C $DOTFILES_DIR stash list   (then: git stash apply <entry>)"
                    fi
                    ;;
                1) echo "==> Discarding local changes." ;;
                2) DOTFILES_UPDATE=0; echo "==> Keeping local changes; setup runs with the local version." ;;
                *) echo "==> Setup aborted; nothing was changed in $DOTFILES_DIR."; exit 1 ;;
            esac
        fi

        if [ "$DOTFILES_UPDATE" = 1 ]; then
            git -C "$DOTFILES_DIR" reset --hard origin/main
        fi
    elif [ -e "$DOTFILES_DIR" ]; then
        echo "[!] $DOTFILES_DIR exists but is not a git clone of the dotfiles." >&2
        echo "    Move it away (or set DOTFILES_DIR to another path) and run setup again; nothing was changed there." >&2
        exit 1
    else
        echo "==> Cloning dotfiles from GitHub..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        verify_or_stop HEAD
    fi

    echo "==> Restarting setup using the latest version of $DOTFILES_DIR/setup.sh..."
    chmod +x "$DOTFILES_DIR/setup.sh"
    export DOTFILES_SETUP_RELOADED=1
    exec bash "$DOTFILES_DIR/setup.sh" "$@"
fi

# ==========================================
# Shared helpers (log/ok/warn/try, verified downloads, links, fonts, machine type)
# ==========================================
SETUP_LIB="$DOTFILES_DIR/scripts/lib"
# shellcheck source-path=SCRIPTDIR source=scripts/lib/common.sh
source "$SETUP_LIB/common.sh"
# shellcheck source-path=SCRIPTDIR source=scripts/lib/github-download.sh
source "$SETUP_LIB/github-download.sh"
# shellcheck source-path=SCRIPTDIR source=scripts/lib/bootstrap.sh
source "$SETUP_LIB/bootstrap.sh"
# shellcheck source-path=SCRIPTDIR source=scripts/lib/fonts.sh
source "$SETUP_LIB/fonts.sh"
# shellcheck source-path=SCRIPTDIR source=scripts/lib/machine.sh
source "$SETUP_LIB/machine.sh"

# Temp files/dirs made below are removed on exit, also when a step fails
TMP_PATHS=()
cleanup_tmp() { [ "${#TMP_PATHS[@]}" -eq 0 ] || rm -rf "${TMP_PATHS[@]}"; }
trap cleanup_tmp EXIT

# ==========================================
# Setup steps: setup.d/NN-*.sh, sourced in this order (same shell, same variables and helpers)
# ==========================================
# shellcheck source-path=SCRIPTDIR source=setup.d/10-system.sh
source "$DOTFILES_DIR/setup.d/10-system.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/20-appimages.sh
source "$DOTFILES_DIR/setup.d/20-appimages.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/30-cli-tools.sh
source "$DOTFILES_DIR/setup.d/30-cli-tools.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/40-fonts.sh
source "$DOTFILES_DIR/setup.d/40-fonts.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/50-pywal.sh
source "$DOTFILES_DIR/setup.d/50-pywal.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/60-links.sh
source "$DOTFILES_DIR/setup.d/60-links.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/70-hotkeys.sh
source "$DOTFILES_DIR/setup.d/70-hotkeys.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/80-permissions-lockscreen.sh
source "$DOTFILES_DIR/setup.d/80-permissions-lockscreen.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/90-theme.sh
source "$DOTFILES_DIR/setup.d/90-theme.sh"
# shellcheck source-path=SCRIPTDIR source=setup.d/95-network.sh
source "$DOTFILES_DIR/setup.d/95-network.sh"
