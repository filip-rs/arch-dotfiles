#!/usr/bin/env bash
# "Focus mode": blank the desktop's side monitors (DP-2 / DP-3), or wake them.
# Bound to SUPER + CTRL + SHIFT + 0.

source "$HOME/.config/scripts/lib/compositor.sh"

if ! output_is_on DP-2; then
    output_power DP-2 on
    output_power DP-3 on

    notify-send "Enabling displays" "Exiting focus mode"
else
    output_power DP-2 off
    output_power DP-3 off

    notify-send "Disabling displays" "Entering focus mode"
fi
