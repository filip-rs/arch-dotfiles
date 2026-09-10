#!/usr/bin/env bash
# Waybar custom module: the real audio output device.
#
# The default sink on this system is `effect_input.live_eq`, the PipeWire
# filter-chain created by quickshell/music/equalizer.sh (which is what stands in
# for easyeffects here). That node is a plain filter: no card, no device.bus, no
# device.form_factor. Waybar's built-in pulseaudio module reads the default sink
# and therefore can never tell that a Bluetooth headset is connected.
#
# This script follows the filter-chain's output link to the device actually
# playing the audio and reports *that* — while still reading volume and mute
# from the default sink, since that is what the volume keys control.
#
# Streams: emits one JSON line per PipeWire/PulseAudio event.

set -uo pipefail

# Glyphs, lifted byte for byte from the pulseaudio module of the pre-port
# waybar config so the bar keeps the same look.
ICON_SPEAKER=""
ICON_HEADPHONE=""
ICON_HEADSET=""
ICON_HANDSFREE=""
ICON_MUTED=""

EQ_SINK="effect_input.live_eq"
EQ_OUT="effect_output.live_eq"

# Resolve the node the EQ chain feeds into. Empty if the chain isn't in use.
eq_target() {
    pw-link -o -l 2>/dev/null | awk -v n="^${EQ_OUT}:output_FL$" '
        $0 ~ n { getline
                 if ($0 ~ /\|->/) { sub(/.*\|-> */, ""); sub(/:.*/, ""); print; exit } }'
}

# All properties of one sink, as `key = value` lines.
sink_props() {
    pactl list sinks | awk -v want="$1" '
        /^Sink #/          { inblock = 0 }
        $1 == "Name:"      { inblock = ($2 == want) }
        inblock            { print }'
}

prop() { sed -n "s/^[[:space:]]*$2 = \"\?\([^\"]*\)\"\?$/\1/p" <<< "$1" | head -1; }

# Active bluetooth profile for a MAC, e.g. a2dp-sink / headset-head-unit.
bt_profile() {
    local mac_us="${1//:/_}"
    pactl list cards | awk -v want="bluez_card.${mac_us}" '
        /^Card #/     { inblock = 0 }
        $1 == "Name:" { inblock = ($2 == want) }
        inblock && /Active Profile:/ { print $3; exit }'
}

# AirPods battery via the librepods daemon, if it is running.
pods_battery() {
    command -v busctl >/dev/null || return 0
    busctl --user --no-pager get-property me.kavishdevar.librepods \
        /me/kavishdevar/librepods me.kavishdevar.Battery All 2>/dev/null \
        | tr -d '"' | awk '{$1=""; print $0}' | xargs 2>/dev/null
}

emit() {
    local default_sink volume mute real props desc bus form icon mac profile
    local text tooltip class

    default_sink=$(pactl get-default-sink 2>/dev/null) || default_sink=""
    [ -n "$default_sink" ] || { printf '{"text":"","tooltip":"no audio server"}\n'; return; }

    volume=$(pactl get-sink-volume "$default_sink" 2>/dev/null | grep -oP '\d+(?=%)' | head -1)
    volume=${volume:-0}
    mute=$(pactl get-sink-mute "$default_sink" 2>/dev/null | awk '{print $2}')

    # Identity comes from the device behind the EQ chain, not the chain itself.
    real="$default_sink"
    if [ "$default_sink" = "$EQ_SINK" ]; then
        real=$(eq_target)
        real=${real:-$default_sink}
    fi

    props=$(sink_props "$real")
    desc=$(sed -n 's/^[[:space:]]*Description: //p' <<< "$props" | head -1)
    bus=$(prop "$props" "device.bus")
    form=$(prop "$props" "device.form_factor")
    icon=$(prop "$props" "device.icon_name")
    mac=$(prop "$props" "api.bluez5.address")

    class="speaker"
    local glyph="$ICON_SPEAKER"

    case "$form" in
        headset)           class="headphones"; glyph="$ICON_HEADSET" ;;
        headphone)         class="headphones"; glyph="$ICON_HEADPHONE" ;;
        hands-free)        class="headphones"; glyph="$ICON_HANDSFREE" ;;
        speaker|internal)  class="speaker";    glyph="$ICON_SPEAKER" ;;
        *)
            case "$icon" in
                *headset*|*headphone*) class="headphones"; glyph="$ICON_HEADSET" ;;
            esac
            ;;
    esac

    tooltip="${desc:-$real}"

    if [ "$bus" = "bluetooth" ]; then
        class="bluetooth"
        [ "$glyph" = "$ICON_SPEAKER" ] && glyph="$ICON_HEADSET"
        profile=$(bt_profile "$mac")
        case "$profile" in
            a2dp-sink*)        tooltip="$tooltip — A2DP (hi-fi)" ;;
            headset-head-unit*) tooltip="$tooltip — HFP (call mode)"; class="bluetooth-hfp" ;;
            "")                : ;;
            *)                 tooltip="$tooltip — $profile" ;;
        esac
        local batt
        batt=$(pods_battery)
        [ -n "$batt" ] && tooltip="$tooltip"$'\n'"Battery: $batt"
    fi

    if [ "$default_sink" = "$EQ_SINK" ]; then
        tooltip="$tooltip"$'\n'"via Live EQ"
    fi

    if [ "$mute" = "yes" ]; then
        text="$ICON_MUTED  Muted"
        class="muted"
    else
        text="$glyph  ${volume}%"
    fi

    # Waybar closing our stdout is how a module is told to stop. bash reports that
    # as an EPIPE return from the write rather than killing us with SIGPIPE, so
    # without an explicit exit the loop below runs forever against a dead pipe --
    # one leaked process per waybar restart, each still holding the terminal that
    # waybar was started from and printing "write error: Broken pipe" into it on
    # every event it wakes for. The write's own stderr is dropped so the exit is
# silent -- bash would otherwise announce the EPIPE before we act on it.
    printf '{"text":%s,"tooltip":%s,"class":%s,"percentage":%d}\n' \
        "$(json_str "$text")" "$(json_str "$tooltip")" "$(json_str "$class")" "$volume" 2>/dev/null || exit 0
}

json_str() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

emit

# Re-emit on any sink / card / server change. `pactl subscribe` is chatty, so
# coalesce bursts into a single update.
#
# Fed by process substitution rather than `pactl subscribe | while`: a pipeline
# would put this loop in a subshell, which waybar does not know about and so
# cannot kill. That subshell outlived every waybar restart and kept writing to
# the dead pipe. Read this way the loop runs in the main shell, so the exit in
# emit() actually ends the script and `pactl subscribe` gets EPIPE and follows.
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

# `exec` inside the substitution so no stray bash is left wrapping the feeder.
exec 3< <(exec "${DIEWITH[@]}" pactl subscribe 2>/dev/null)
FEEDER=$!

while read -r line <&3; do
    case "$line" in
        *" on sink "*|*" on card "*|*" on server "*|*" on sink-input "*)
            # drain the rest of the burst
            while read -r -t 0.1 _ <&3; do :; done
            emit
            ;;
    esac
done
