#!/usr/bin/env bash
# Waybar custom module: Mullvad tunnel state.
#
# Replaces the tray icon the Electron GUI used to provide. `mullvad-daemon`
# holds the tunnel, so this needs nothing running but the daemon itself.
#
# Streams rather than polls: `mullvad status listen` blocks until the daemon
# reports a transition, so an idle tunnel costs no wakeups. A poll loop at the
# 1-2s a VPN indicator would need is exactly the kind of background timer worth
# not having on a laptop.

set -uo pipefail

# Material Design pair, to match the weight of the bluetooth/wifi/battery
# glyphs on the bar. Closed padlock = tunnel up, open = unprotected. The bar
# shows the icon alone; everything else lives in the tooltip.
ICON_ON="󰌾"   # nf-md-lock
ICON_OFF="󰍁"  # nf-md-lock_open

emit() {
    local json state text class tooltip
    json=$(mullvad status -j 2>/dev/null)

    if [ -z "$json" ]; then
        # Daemon down or not responding -- say so rather than claiming "off",
        # which would read as "not protected but working".
        printf '{"text":"%s","class":"unavailable","tooltip":"mullvad-daemon unreachable"}\n' "$ICON_OFF" 2>/dev/null || exit 0
        return
    fi

    state=$(jq -r '.state // "unknown"' <<<"$json")

    case "$state" in
        connected)
            text="$ICON_ON"
            class="connected"
            tooltip=$(jq -r '
                .details as $d
                | "Connected  \($d.location.hostname // "?")"
                + "\n\($d.location.city // "?"), \($d.location.country // "?")"
                + "\n\($d.location.ipv4 // "?")"
                + (if ($d.feature_indicators // []) | length > 0
                   then "\n" + ($d.feature_indicators
                                | map(gsub("(?<a>[a-z])(?<b>[A-Z])"; "\(.a) \(.b)"))
                                | join(", "))
                   else "" end)' <<<"$json")
            ;;
        connecting)
            # Still open until the handshake lands -- the icon should not claim
            # protection the tunnel does not yet have.
            text="$ICON_OFF"; class="connecting"; tooltip="Connecting…"
            ;;
        disconnecting)
            text="$ICON_OFF"; class="connecting"; tooltip="Disconnecting…"
            ;;
        error)
            # Lockdown mode blocking traffic is a distinct, important state:
            # the tunnel is down *and* the network is intentionally cut. Closed
            # padlock in red -- sealed, but not by a working tunnel.
            text="$ICON_ON"; class="blocked"
            tooltip=$(jq -r '"Blocked: " + (.details.blocking_error // .details.cause // "traffic is being blocked")' <<<"$json" 2>/dev/null)
            ;;
        *)
            text="$ICON_OFF"; class="disconnected"; tooltip="Disconnected — traffic is not protected"
            ;;
    esac

    # jq -c builds the object so tooltips containing quotes or newlines stay
    # valid JSON; waybar drops the module entirely on a parse error.
    # Waybar closing our stdout is how a module is told to stop. bash reports that
    # as an EPIPE return from the write rather than killing us with SIGPIPE, so
    # without an explicit exit the loop below runs forever against a dead pipe --
    # one leaked process per waybar restart, each still holding the terminal that
    # waybar was started from and printing "write error: Broken pipe" into it on
    # every event it wakes for. The write's own stderr is dropped so the exit is
# silent -- bash would otherwise announce the EPIPE before we act on it.
    jq -nc --arg t "$text" --arg c "$class" --arg tt "$tooltip" \
        '{text:$t, class:$c, tooltip:$tt}' || exit 0
}

emit

# Waybar stops a module by killing the pid it spawned, and SIGKILL cannot be
# trapped -- so a long-lived child of ours (the event feeder below) would be
# left behind, one per waybar restart. PR_SET_PDEATHSIG has the kernel signal it
# for us when we die, however we die. Empty where setpriv is missing (this
# config is shared across machines); the EXIT trap still covers the ordinary
# pipe-closed path there.
if command -v setpriv >/dev/null 2>&1 && setpriv --pdeathsig TERM true 2>/dev/null; then
    DIEWITH=(setpriv --pdeathsig TERM)
else
    DIEWITH=()
fi

# Waybar kills only the pid it spawned, and a process-substitution feeder is not
# that pid -- left alone it lingers until its next write, leaking one stray
# listener per waybar restart. Reap it on the way out instead. TERM/HUP are
# trapped alongside EXIT because bash does not run an EXIT trap when it is
# killed by an untrapped signal, which is exactly how waybar stops a module.
_reap() {
    trap - EXIT TERM INT HUP
    [ -n "${FEEDER:-}" ] && kill "$FEEDER" 2>/dev/null
    exit 0
}
trap _reap EXIT TERM INT HUP

# Re-emit on every daemon-reported transition. `status listen` blocks and prints
# one line per change; if it exits (daemon restart, CLI upgrade) re-emit once and
# back off before re-attaching, so the bar never goes stale or spins.
while true; do
    # `listen` prints the whole status block per event (state line, then
    # indented detail lines). Only the unindented state line is a transition;
    # emitting on the detail lines would redraw the bar three extra times --
    # hence the case that skips indented and blank lines.
    #
    # Fed by process substitution rather than a `| while` pipeline, and filtered
    # here rather than through grep, so that neither the loop nor the filter
    # needs a subshell: waybar only knows about the pid it spawned, so any extra
    # bash survives its death and keeps writing to the closed pipe. With this
    # shape the exit in emit() ends the script for real.
    # `exec` inside the substitution so no stray bash wraps the feeder.
    exec 3< <(exec "${DIEWITH[@]}" mullvad status listen 2>/dev/null)
    FEEDER=$!

    while read -r _line <&3; do
        case "$_line" in
            ""|[[:space:]]*) continue ;;
        esac
        emit
    done
    exec 3<&-
    emit
    sleep 5
done
