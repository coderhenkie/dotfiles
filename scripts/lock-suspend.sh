#!/usr/bin/env bash
# ==========================================
# Suspend after being locked for a while (bare metal only)
# ==========================================
# Started once per login from i3/config. Every 30s it checks whether the
# session is locked (light-locker screensaver active AND our X session no
# longer the active one on the seat, i.e. the LightDM greeter is showing).
# Once it has been locked for LOCK_SUSPEND_AFTER seconds (default 1800 = 30 min)
# it runs `systemctl suspend`. After waking up the timer restarts, so a machine
# woken by accident and left locked goes back to sleep 30 minutes later.
#
# Virtual machines are skipped: suspending a VM freezes the guest and it often
# does not wake up cleanly (the host decides when the VM sleeps instead).
#
# A locked session is "inactive" for logind, which needs admin auth to suspend;
# setup.sh installs /etc/polkit-1/rules.d/50-lock-suspend.rules on bare metal to allow it.
#
# Usage:
#   lock-suspend.sh            run the watcher (single instance)
#   lock-suspend.sh --status   show machine type and current lock state

# No set -e: background daemon loop where light-locker-command and systemctl may return non-zero.
set -uo pipefail

# shellcheck source-path=SCRIPTDIR source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=lib/machine.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/machine.sh"

case "${1:-}" in
    -h|--help) help_from_header; exit 0 ;;
esac

SUSPEND_AFTER="${LOCK_SUSPEND_AFTER:-1800}"
POLL_INTERVAL=30
SESSION="${XDG_SESSION_ID:-self}"

is_locked() {
    # light-locker reports the screensaver as active while the lock is up
    LC_ALL=C light-locker-command -q 2>/dev/null | grep -q 'is active' || return 1
    # ...and the greeter has taken over the seat, so our session is inactive
    [ "$(loginctl show-session "$SESSION" -p Active --value 2>/dev/null || true)" = "no" ]
}

if [ "${1:-}" = "--status" ]; then
    echo "Machine:        $(machine_type)"
    if machine_is_vm; then
        echo "Auto-suspend:   disabled (virtual machine)"
    else
        echo "Auto-suspend:   after $((SUSPEND_AFTER / 60)) min locked"
    fi
    if is_locked; then echo "Session:        locked"; else echo "Session:        unlocked"; fi
    if pgrep -f 'scripts/lock-suspend.sh$' >/dev/null; then echo "Watcher:        running"; else echo "Watcher:        not running"; fi
    exit 0
fi

if machine_is_vm; then
    warn "lock-suspend: $(machine_type) detected, auto-suspend disabled."
    exit 0
fi

i3_env
# Single instance per user (i3 restarts must not start a second watcher)
single_instance lock-suspend

locked_since=""
while session_alive; do
    now=$(date +%s)
    if is_locked; then
        [ -z "$locked_since" ] && locked_since=$now
        if [ $((now - locked_since)) -ge "$SUSPEND_AFTER" ]; then
            logger -t lock-suspend "locked for $((now - locked_since))s, suspending"
            systemctl suspend || logger -t lock-suspend "systemctl suspend failed (polkit rule missing? run setup.sh)"
            # Restart the timer after resume (or after a failed attempt)
            locked_since=$(date +%s)
        fi
    else
        locked_since=""
    fi
    sleep "$POLL_INTERVAL"
done
