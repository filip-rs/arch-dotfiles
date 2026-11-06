#!/usr/bin/env bash
# Lock the session with the Quickshell lockscreen (shell.qml next to this file).
# Every way of locking goes through here: keybinds, hypridle, wlogout.
#
# Why a crash can't leave the machine unlocked:
#   1. ext-session-lock-v1: once Hyprland has confirmed the lock, it only lifts
#      when the lock client explicitly unlocks, and shell.qml does that only
#      after a successful PAM conversation. If the client crashes or is killed
#      instead, Hyprland keeps every output covered ("lockscreen died") and
#      sends input nowhere.
#   2. This script sees the client exit without having reported "unlocked" and
#      starts a new one, which takes over the dead lock. That needs
#      misc.allow_session_lock_restore = true (hypr/lua/looknfeel.lua).
#   3. If a client doesn't load (QML error, missing module, ...), doesn't get
#      the lock confirmed, or keeps dying, hyprlock takes over.
#
# If the lock UI is ever wedged (frozen, input dead), run this from a TTY to
# swap it for hyprlock without unlocking anything:
#     ~/.config/quickshell/lock/lock.sh --fallback
# Log: $XDG_RUNTIME_DIR/qslock/lock.log

set -uo pipefail

LOCK_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$UID}
STATE_DIR=${QSLOCK_STATE_DIR:-$RUNTIME_DIR/qslock}
STATE_FILE=$STATE_DIR/state
PID_FILE=$STATE_DIR/supervisor.pid
LOG_FILE=$STATE_DIR/lock.log

# A client first reports "requested" (its config loaded and it asked for the
# lock), then "locked" once Hyprland confirms. Confirmation waits for a frame on
# every output and Hyprland only gives up waiting after 5s, which happens when
# the screens are already off (hypridle locks and turns DPMS off together), so
# that stage gets a generous timeout. A broken config still falls back fast.
LOAD_TIMEOUT=4  # seconds to reach "requested"
LOCK_TIMEOUT=12 # further seconds to reach "locked"
MAX_RESTARTS=3  # client deaths per lock before switching to hyprlock

mkdir -p -- "$STATE_DIR"
log() { printf '%(%F %T)T [%d] %s\n' -1 "$$" "$*" >>"$LOG_FILE"; }

if [[ ${1-} == --fallback ]]; then
    if pid=$(cat -- "$PID_FILE" 2>/dev/null) && kill -USR1 "$pid" 2>/dev/null; then
        echo "lock.sh: asked supervisor $pid to switch to hyprlock"
        exit 0
    fi
    echo "lock.sh: no lock supervisor running" >&2
    exit 1
fi

# One lock at a time. Only this process holds the guard (the client gets the fd
# closed), so a stray client process can never keep later locks from starting.
exec 9>"$STATE_DIR/supervisor.lock"
flock -n 9 || exit 0

echo "$$" >"$PID_FILE"
trap 'rm -f -- "$PID_FILE"' EXIT
trap 'want_fallback=1' USR1
trap '' HUP # outlive whatever launched us
want_fallback=0
child=

state() { cat -- "$STATE_FILE" 2>/dev/null; }

compositor_alive() {
    local sock=${WAYLAND_DISPLAY:-wayland-0}
    [[ $sock == /* ]] || sock=$RUNTIME_DIR/$sock
    [[ -S $sock ]]
}

# wait_state SECONDS STATE...: until the client reports one of STATE.
# Returns 1 on timeout, 2 if the client exits first.
wait_state() {
    local secs=$1 i s want
    shift
    for ((i = 0; i < secs * 10; i++)); do
        s=$(state)
        for want; do [[ $s == "$want" ]] && return 0; done
        kill -0 "$child" 2>/dev/null || return 2
        sleep 0.1
    done
    return 1
}

# Start a lock client and wait for it to get the session locked.
#
# QS_DISABLE_CRASH_HANDLER: Quickshell's own crash handler relaunches the shell
# without its --path, leaving an orphan that loads nothing and never exits.
# This script does the restarting instead.
start_client() {
    rm -f -- "$STATE_FILE"
    QSLOCK_STATE_FILE=$STATE_FILE QS_DISABLE_CRASH_HANDLER=1 \
        quickshell --no-duplicate --path "$LOCK_DIR" >>"$LOG_FILE" 2>&1 9>&- &
    child=$!
    log "started lock client $child"
    local rc
    wait_state "$LOAD_TIMEOUT" requested locked
    rc=$?
    if ((rc != 0)); then
        ((rc == 2)) && fail_reason="client exited while loading (see quickshell errors above)" \
                    || fail_reason="client didn't load within ${LOAD_TIMEOUT}s"
        return 1
    fi
    wait_state "$LOCK_TIMEOUT" locked
    rc=$?
    if ((rc != 0)); then
        ((rc == 2)) && fail_reason="client exited before the lock was confirmed" \
                    || fail_reason="lock not confirmed within ${LOCK_TIMEOUT}s"
        return 1
    fi
    log "lock confirmed"
}

fallback() {
    log "switching to hyprlock: $*"
    if [[ -n $child ]]; then
        kill -KILL "$child" 2>/dev/null
        wait "$child" 2>/dev/null
        child=
    fi
    local try rc
    for try in 1 2 3; do
        hyprlock 9>&-
        rc=$?
        if ((rc == 0)); then
            log "unlocked (hyprlock)"
            exit 0
        fi
        log "hyprlock exited with $rc (try $try)"
        compositor_alive || exit 0
        sleep 1
    done
    log "hyprlock failed 3 times; leaving the session as the compositor has it"
    exit 1
}

fail_reason=
start_client || fallback "$fail_reason"

restarts=0
while :; do
    ((want_fallback)) && fallback "requested with --fallback"
    wait "$child"
    status=$?
    ((want_fallback)) && fallback "requested with --fallback"
    kill -0 "$child" 2>/dev/null && continue # wait was interrupted, client still running

    if [[ $(state) == unlocked ]]; then
        log "unlocked"
        exit 0
    fi
    compositor_alive || { log "compositor gone, stopping"; exit 0; }

    log "lock client $child died while locked (status $status)"
    child=
    ((++restarts > MAX_RESTARTS)) && fallback "client died $restarts times"
    sleep 0.5
    start_client || fallback "restarted $fail_reason"
done
