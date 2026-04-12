#!/usr/bin/env bash

ACTION=$1
TYPE=$2
ID=$3
VAL=$4

case $ACTION in
    set-volume)
        # Type should be 'sink', 'source', or 'sink-input'
        pactl set-$TYPE-volume "$ID" "$VAL%"
        ;;
    toggle-mute)
        pactl set-$TYPE-mute "$ID" toggle
        ;;
    set-default)
        # For setting defaults, we need to use the name rather than the index
        pactl set-default-$TYPE "$ID"
        ;;
    get-port)
        pactl --format=json list sinks | python3 -c "
import json,sys
for s in json.load(sys.stdin):
    ports=[p.get('name','') for p in s.get('ports',[])]
    if 'analog-output-headphones' in ports and 'analog-output-lineout' in ports:
        print('headphones' if 'headphone' in s.get('active_port','') else 'lineout')
        sys.exit()
print('none')"
        ;;
    toggle-port)
        bash "$HOME/.config/hypr/scripts/speaker_toggle.sh"
        ;;
esac
