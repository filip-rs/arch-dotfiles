#!/usr/bin/env bash
# "Focus mode": blank the desktop's side monitors (DP-2 / DP-3), or wake them.
# Bound to SUPER + CTRL + SHIFT + 0.

if [ "$(hyprctl monitors -j | jq '.[] | select(.name == "DP-2") | .dpmsStatus')" = "false" ]; then
    hyprctl dispatch 'hl.dsp.dpms({ action = "on", monitor = "DP-2" })'
    hyprctl dispatch 'hl.dsp.dpms({ action = "on", monitor = "DP-3" })'

    notify-send "Enabling displays" "Exiting focus mode"
else
    hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "DP-2" })'
    hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "DP-3" })'

    notify-send "Disabling displays" "Entering focus mode"
fi
