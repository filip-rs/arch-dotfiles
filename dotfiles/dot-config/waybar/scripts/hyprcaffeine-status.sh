#!/usr/bin/env bash
# Waybar custom module: idle-inhibition state, via hyprcaffeine.
#
# A thin adapter over `hyprcaffeine waybar` rather than a reimplementation --
# hyprcaffeine owns the state, the glyphs and the CSS class names, and this
# stays out of the way so a package upgrade keeps working. It exists to fix
# three things about calling that command directly, which is how the vendor's
# `hyprcaffeine waybar-setup` wires the module:
#
#   1. The vendor text counts a running timer down in seconds ("28m 45s"), so
#      the module changes width once a second. In a merged pill that shoves
#      every segment to its right sideways, the tray included. Rounded to whole
#      minutes here, with the exact figure left in the tooltip.
#   2. waybar-setup pairs it with `"interval": 2`, i.e. a bash+jq wakeup every
#      two seconds forever, for a value that changes a handful of times a day.
#      This blocks on the state file instead and only ticks while a timer is
#      actually counting -- same reasoning as mullvad-status.sh next door.
#   3. The JSON carries a hardcoded Catppuccin "color" field. waybar has no such
#      field in a custom module (waybar-custom(5) parses text/tooltip/class/
#      percentage only) so it was always inert, but dropping it makes it clear
#      the colour comes from style.css, which theme_apply.sh can actually reach.

set -uo pipefail

STATE_DIR="$HOME/.cache/hyprcaffeine"
STATE_FILE="$STATE_DIR/state.json"

# Seconds between redraws while a timer is counting down. The bar shows whole
# minutes, so this only decides how stale that minute is allowed to look.
TICK=15

# This config is shared with machines that have no hyprcaffeine. Empty text
# makes waybar drop the module, which is why style.css keeps it a middle
# segment of the tray pill and never a cap.
if ! command -v hyprcaffeine >/dev/null 2>&1; then
    echo '{"text":""}'
    exit 0
fi

emit() {
    local json

    # jq rewrites .text rather than rebuilding it: the glyph vocabulary is
    # hyprcaffeine's (cup, loop, timer, monitor, lid) and worth inheriting.
    #
    # "28m 45s" -> "28m", and anything under a minute rounds up to "1m". Note
    # the deliberate absence of a "<1m": waybar renders module text as pango
    # markup, so a bare "<" is a malformed tag and takes the module out.
    json=$(hyprcaffeine waybar 2>/dev/null | jq -c '
        del(.color)
        | .text |= (gsub("(?<a>[0-9]+m) [0-9]+s"; .a) | gsub("[0-9]+s"; "1m"))
    ' 2>/dev/null)

    # A wedged or half-upgraded hyprcaffeine should read as "not holding
    # anything", not as a stale timer that never moves.
    if [ -z "$json" ]; then
        json='{"text":"󰛊","class":"hc-off","tooltip":"hyprcaffeine unreachable"}'
    fi

    # Waybar closing our stdout is how a module is told to stop. bash reports that
    # as an EPIPE return from the write rather than killing us with SIGPIPE, so
    # without an explicit exit the loop below runs forever against a dead pipe --
    # one leaked process per waybar restart, each still holding the terminal that
    # waybar was started from and printing "write error: Broken pipe" into it on
    # every event it wakes for. The write's own stderr is dropped so the exit is
# silent -- bash would otherwise announce the EPIPE before we act on it.
    printf '%s\n' "$json" 2>/dev/null || exit 0
}

# True while a countdown is running. Infinite mode (duration 0) holds suspend
# open with no clock attached, so it needs no tick -- the next state change is
# the only thing that can alter what is drawn.
timer_running() {
    [ -r "$STATE_FILE" ] || return 1
    jq -e '.status == "active" and .duration != 0' "$STATE_FILE" >/dev/null 2>&1
}

# Waybar stops a module by killing the pid it spawned, and SIGKILL cannot be
# trapped -- so a long-lived child of ours (inotifywait below) would be
# left behind, one per waybar restart. PR_SET_PDEATHSIG has the kernel signal it
# for us when we die, however we die. Empty where setpriv is missing (this
# config is shared across machines); the EXIT trap still covers the ordinary
# pipe-closed path there.
if command -v setpriv >/dev/null 2>&1 && setpriv --pdeathsig TERM true 2>/dev/null; then
    DIEWITH=(setpriv --pdeathsig TERM)
else
    DIEWITH=()
fi

# inotifywait needs the directory to exist before it can watch it, and on a
# fresh install nothing has written state yet; hyprcaffeine's own state_init
# creates the same path.
mkdir -p "$STATE_DIR"

emit

# Watch the directory rather than the file: state is rewritten in place today
# (state.sh uses `cat >`), but a future version replacing it via a temp file and
# mv would silently break a watch pinned to the inode.
#
# -t 0 blocks indefinitely (inotifywait(1)), so an idle machine costs nothing;
# while a timer runs the timeout turns the same wait into the redraw tick.
while true; do
    if timer_running; then
        "${DIEWITH[@]}" inotifywait -qq -t "$TICK" -e close_write,create,moved_to "$STATE_DIR" 2>/dev/null
    else
        "${DIEWITH[@]}" inotifywait -qq -e close_write,create,moved_to "$STATE_DIR" 2>/dev/null
    fi
    rc=$?

    # 0 is an event and 2 is the timeout tick; both are ordinary. Anything else
    # is a failed watch -- inotify-tools absent (127), the watch limit hit, the
    # directory pulled out from under us (1) -- and would spin this loop hot.
    # Degrade to a TICK-paced poll instead, so the bar still tracks state.
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
        sleep "$TICK"
    fi

    emit
done
