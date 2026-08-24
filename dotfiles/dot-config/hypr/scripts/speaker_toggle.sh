#!/usr/bin/env bash
# Toggle the analog output between line-out (speakers) and headphones.
# Bound to SUPER + CTRL + SHIFT + 7.
#
# The sink is discovered rather than hardcoded: the previous version pinned
# alsa_output.pci-0000_75_00.6.analog-stereo, which is the desktop's PCI path
# and does not exist on the laptop.

SINK=$(pactl list short sinks | awk '$2 ~ /^alsa_output\..*analog/ {print $2; exit}')

if [ -z "$SINK" ]; then
    notify-send "Audio" "No analog output sink found"
    exit 1
fi

CURRENT=$(pactl --format=json list sinks | python3 -c "
import json, sys
want = sys.argv[1]
for s in json.load(sys.stdin):
    if s['name'] == want:
        print(s['active_port'] or '')
        break
" "$SINK")

if [[ "$CURRENT" == *"headphones"* ]]; then
    pactl set-sink-port "$SINK" analog-output-lineout && notify-send "Audio: Speakers (Line Out)"
else
    pactl set-sink-port "$SINK" analog-output-headphones && notify-send "Audio: Headphones"
fi
